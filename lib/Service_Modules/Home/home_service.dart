import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'home_UI.dart';
import 'dart:async';

class HomeService {
  final FirebaseFirestore _db;
  // Add simple caching for academic IDs
  final Map<String, Map<String, String>> _academicIdsCache = {};

  HomeService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ============================ USER + NOTES ============================

  DocumentReference<Map<String, dynamic>> _userDoc({
    required String role,
    required String uid,
  }) {
    return _db.collection('users').doc(role).collection('accounts').doc(uid);
  }

  Future<Map<String, dynamic>?> fetchUserDetails({
    required String role,
    required String uid,
  }) async {
    final snap = await _userDoc(role: role, uid: uid).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<String> getOrCreateNote({
    required String role,
    required String uid,
  }) async {
    final noteRef = _userDoc(role: role, uid: uid).collection('meta').doc('note');
    final snap = await noteRef.get();
    if (!snap.exists) {
      await noteRef.set({'text': 'Tap to write notes'});
      return 'Tap to write notes';
    }
    return (snap.data()?['text'] ?? 'Tap to write notes').toString();
  }

  Future<void> saveNote({
    required String role,
    required String uid,
    required String text,
  }) {
    final noteRef = _userDoc(role: role, uid: uid).collection('meta').doc('note');
    return noteRef.set({'text': text});
  }

  Future<void> resetNote({
    required String role,
    required String uid,
  }) {
    final noteRef = _userDoc(role: role, uid: uid).collection('meta').doc('note');
    return noteRef.set({'text': 'Tap to write notes'});
  }

  Stream<int> streamUnreadCount({
    required String role,
    required String uid,
  }) {
    final q = _db.collection('notifications').where('toRole', isEqualTo: role).where('toUid', isEqualTo: uid).where('read', isEqualTo: false);
    return q.snapshots().map((s) => s.size);
  }

  // ============================ ACADEMIC PATH (IDs) ============================

  Future<Map<String, String>?> _findActiveAcademicIds() async {
    // Check cache first
    const cacheKey = 'activeAcademicIds';
    if (_academicIdsCache.containsKey(cacheKey)) {
      return _academicIdsCache[cacheKey];
    }

    final yearQuery = _db.collection('academic_years').where('status', isEqualTo: 'Active').limit(1);
    final yearSnap = await yearQuery.get();

    if (yearSnap.docs.isEmpty) {
      return null;
    }
    final activeYearId = yearSnap.docs.first.id;

    final semesterQuery = _db.collection('academic_years').doc(activeYearId).collection('semesters').where('status', isEqualTo: 'Active').limit(1);
    final semesterSnap = await semesterQuery.get();

    if (semesterSnap.docs.isEmpty) {
      return null;
    }
    final activeSemesterId = semesterSnap.docs.first.id;

    final result = {'academicYearId': activeYearId, 'semesterId': activeSemesterId};

    // Store in cache
    _academicIdsCache[cacheKey] = result;
    return result;
  }

  // ============================ SCHEDULES ============================

  // NEW IMPROVED IMPLEMENTATION using collection group queries
  Stream<List<ScheduleItem>> streamSchedulesForStudent({
    required String role,
    required String uid,
  }) async* {
    final activeIds = await _findActiveAcademicIds();
    if (activeIds == null) {
      yield [];
      return;
    }

    final todayKey = _todayDay();

    try {
      // 1. First, get the user's document to retrieve their ID field
      final userDoc = await _userDoc(role: role, uid: uid).get();
      if (!userDoc.exists || userDoc.data() == null) {
        yield [];
        return;
      }

      final userData = userDoc.data()!;
      final studentIdField = _strOrNull(userData['userId']) ?? _strOrNull(userData['id']);

      if (studentIdField == null) {
        // No ID field found in user document, can't proceed
        yield [];
        return;
      }

      // For UI purposes, we still need section name
      final sectionName = _strOrNull(userData['sectionName']);

      // 2. Create a controller to manage the stream
      final controller = StreamController<List<ScheduleItem>>();

      // 3. Create path patterns for filtering
      final termPathPattern = 'academic_years/${activeIds['academicYearId']}/semesters/${activeIds['semesterId']}';

      // 4. Set up the collection group query for enrolled_students
      // This query finds all documents in any enrolled_students collection
      // where the studentId field matches the student's ID field
      final enrollmentsQuery = _db.collectionGroup('enrolled_students')
          .where('studentId', isEqualTo: studentIdField);

      // 5. Set up the subscription to listen for changes
      final subscription = enrollmentsQuery.snapshots().listen((snapshot) async {
        final scheduleItems = <ScheduleItem>[];
        final processedScheduleIds = <String>{};

        // Filter to only include documents in the active term and that are for today
        for (final doc in snapshot.docs) {
          final path = doc.reference.path;

          // Check if this enrollment is in the current term
          if (!path.contains(termPathPattern)) continue;

          // Get the parent schedule reference
          final scheduleRef = doc.reference.parent.parent;
          if (scheduleRef == null) continue;

          // Check if we've already processed this schedule
          if (processedScheduleIds.contains(scheduleRef.id)) continue;
          processedScheduleIds.add(scheduleRef.id);

          // Get the schedule document
          final scheduleDoc = await scheduleRef.get();
          if (!scheduleDoc.exists) continue;

          // Check if this schedule is for today
          final scheduleData = scheduleDoc.data();
          if (scheduleData == null) continue;

          final days = scheduleData['days'] as List<dynamic>?;
          if (days == null || !days.contains(todayKey)) continue;

          // Get section name from path if needed
          String? currentSectionName = sectionName;
          if (currentSectionName == null) {
            // Try to extract section name from path or parent document
            final sectionRef = scheduleRef.parent.parent;
            if (sectionRef != null) {
              final sectionDoc = await sectionRef.get();
              currentSectionName = _strOrNull(sectionDoc.data()?['sectionName']);
            }
          }

          // Map to schedule item
          final scheduleItem = _mapSingleDocToScheduleItem(
              scheduleDoc,
              sectionName: currentSectionName
          );

          scheduleItems.add(scheduleItem);
        }

        // Sort items by start time
        scheduleItems.sort((a, b) =>
            _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime))
        );

        // Emit the updated list
        controller.add(scheduleItems);
      }, onError: (e) {
        controller.add([]);
      });

      // 6. Handle cleanup when stream is closed
      controller.onCancel = () {
        subscription.cancel();
      };

      // 7. Yield from controller stream
      yield* controller.stream;

    } catch (e) {
      yield [];
    }
  }

  // Keep original implementation as a fallback
  Stream<List<ScheduleItem>> streamSchedulesForStudentOriginal({
    required String role,
    required String uid,
  }) async* {
    final activeIds = await _findActiveAcademicIds();
    if (activeIds == null) {
      yield [];
      return;
    }

    final todayKey = _todayDay();

    try {
      // 1. First, get the user's section from their profile
      final userDoc = await _userDoc(role: role, uid: uid).get();
      final userData = userDoc.data();

      if (userData == null) {
        yield [];
        return;
      }

      final sectionName = _strOrNull(userData['sectionName']);
      if (sectionName == null || sectionName.isEmpty) {
        yield [];
        return;
      }

      // 2. Get the departments in the active academic year/semester
      final departmentsQuery = _db.collection('academic_years')
          .doc(activeIds['academicYearId'])
          .collection('semesters')
          .doc(activeIds['semesterId'])
          .collection('departments');

      final departmentsSnap = await departmentsQuery.get();

      if (departmentsSnap.docs.isEmpty) {
        yield [];
        return;
      }

      // 3. Set up stream management
      final controller = StreamController<List<ScheduleItem>>();
      final subscriptions = <StreamSubscription>[];
      final allSchedules = <ScheduleItem>[];

      // 4. Search for the section across all departments/courses/year_levels
      for (final deptDoc in departmentsSnap.docs) {
        final coursesQuery = deptDoc.reference.collection('courses');
        final coursesSnap = await coursesQuery.get();

        for (final courseDoc in coursesSnap.docs) {
          final yearLevelsQuery = courseDoc.reference.collection('year_levels');
          final yearLevelsSnap = await yearLevelsQuery.get();

          for (final yearLevelDoc in yearLevelsSnap.docs) {
            final sectionsQuery = yearLevelDoc.reference.collection('sections')
                .where('sectionName', isEqualTo: sectionName);

            final sectionsSnap = await sectionsQuery.get();

            for (final sectionDoc in sectionsSnap.docs) {
              final sectionRef = sectionDoc.reference;

              // For each section, get all its schedules for today
              final schedulesQuery = sectionRef.collection('schedules')
                  .where('days', arrayContains: todayKey);

              final schedulesSnap = await schedulesQuery.get();
              // Check each schedule for enrollment
              for (final scheduleDoc in schedulesSnap.docs) {
                // IMPORTANT: Check if the student is enrolled in this specific schedule
                final enrolledStudentsQuery = scheduleDoc.reference.collection('enrolled_students')
                    .where('studentId', isEqualTo: uid)
                    .limit(1);

                final enrollmentSnap = await enrolledStudentsQuery.get();

                if (enrollmentSnap.docs.isNotEmpty) {
                  // Add this schedule to our list
                  final scheduleItem = _mapSingleDocToScheduleItem(
                      scheduleDoc,
                      sectionName: sectionName
                  );

                  // Check for duplicates before adding
                  if (!allSchedules.any((item) =>
                  item.subjectName == scheduleItem.subjectName &&
                      item.startTime == scheduleItem.startTime)) {
                    allSchedules.add(scheduleItem);
                  }
                }
              }

              // Setup a stream to listen for changes to this section's schedules
              final subscription = schedulesQuery.snapshots().listen(
                      (snapshot) async {
                    // Process any changes to schedules
                    final updatedSchedules = <ScheduleItem>[];

                    for (final scheduleDoc in snapshot.docs) {
                      // Check if the student is enrolled
                      final enrollmentQuery = scheduleDoc.reference.collection('enrolled_students')
                          .where('studentId', isEqualTo: uid)
                          .limit(1);

                      final enrollmentSnap = await enrollmentQuery.get();

                      if (enrollmentSnap.docs.isNotEmpty) {
                        updatedSchedules.add(_mapSingleDocToScheduleItem(
                            scheduleDoc,
                            sectionName: sectionName
                        ));
                      }
                    }

                    // Update the master list
                    for (final schedule in updatedSchedules) {
                      allSchedules.removeWhere((item) =>
                      item.subjectName == schedule.subjectName &&
                          item.startTime == schedule.startTime);
                      allSchedules.add(schedule);
                    }

                    // Sort and emit
                    allSchedules.sort((a, b) =>
                        _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
                    controller.add([...allSchedules]);
                  },
                  onError: (e) {
                  }
              );

              subscriptions.add(subscription);
            }
          }
        }
      }

      // 5. If we found and added any schedules, emit them now
      if (allSchedules.isNotEmpty) {
        allSchedules.sort((a, b) =>
            _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
        controller.add([...allSchedules]);
      } else {
        controller.add([]);
      }

      // 6. Handle cleanup when stream is closed
      controller.onCancel = () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
      };

      // 7. Yield from controller stream
      yield* controller.stream;

    } catch (e) {
      yield [];
    }
  }

  Stream<List<ScheduleItem>> streamSchedulesForTeacher({
    required String teacherUid,
  }) async* {
    final activeIds = await _findActiveAcademicIds();
    if (activeIds == null) {
      yield [];
      return;
    }

    final todayKey = _todayDay();

    try {
      // Get all departments in the active academic year/semester
      final departmentsQuery = _db.collection('academic_years')
          .doc(activeIds['academicYearId'])
          .collection('semesters')
          .doc(activeIds['semesterId'])
          .collection('departments');

      final departmentsSnap = await departmentsQuery.get();

      if (departmentsSnap.docs.isEmpty) {
        yield [];
        return;
      }

      // Create a controller to manage multiple streams
      final controller = StreamController<List<ScheduleItem>>();
      final subscriptions = <StreamSubscription>[];
      final allTeacherSchedules = <ScheduleItem>[];

      // Search for schedules across all departments/courses/year_levels/sections
      for (final deptDoc in departmentsSnap.docs) {
        final coursesQuery = deptDoc.reference.collection('courses');
        final coursesSnap = await coursesQuery.get();

        for (final courseDoc in coursesSnap.docs) {
          final yearLevelsQuery = courseDoc.reference.collection('year_levels');
          final yearLevelsSnap = await yearLevelsQuery.get();

          for (final yearLevelDoc in yearLevelsSnap.docs) {
            final sectionsQuery = yearLevelDoc.reference.collection('sections');
            final sectionsSnap = await sectionsQuery.get();

            for (final sectionDoc in sectionsSnap.docs) {
              final scheduleQuery = sectionDoc.reference.collection('schedules')
                  .where('instructorId', isEqualTo: teacherUid)
                  .where('days', arrayContains: todayKey);

              final sub = scheduleQuery.snapshots().listen(
                      (scheduleSnap) {
                    final sectionName = _strOrNull(sectionDoc.data()['sectionName']);
                    final scheduleItems = scheduleSnap.docs.map((doc) {
                      return _mapSingleDocToScheduleItem(doc, sectionName: sectionName);
                    }).toList();

                    // Update the combined list
                    allTeacherSchedules.removeWhere((item) =>
                        scheduleItems.any((newItem) =>
                        newItem.subjectName == item.subjectName &&
                            newItem.startTime == item.startTime
                        )
                    );
                    allTeacherSchedules.addAll(scheduleItems);

                    // Sort by start time
                    allTeacherSchedules.sort((a, b) =>
                        _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));

                    // Emit the updated list
                    controller.add([...allTeacherSchedules]);
                  },
                  onError: (e) {
                  }
              );

              subscriptions.add(sub);
            }
          }
        }
      }

      // Handle cleanup
      controller.onCancel = () {
        for (final sub in subscriptions) {
          sub.cancel();
        }
      };

      // If no subscriptions were added, yield empty list immediately
      if (subscriptions.isEmpty) {
        yield [];
        return;
      }

      // Yield from controller stream
      yield* controller.stream;
    } catch (e) {
      yield [];
    }
  }

  // ===================== Chip-tap Details Fetching =====================

  Future<InstructorDetails?> fetchInstructorDetails(String instructorId) async {
    try {
      final doc = await _db.collection('users').doc('teacher').collection('accounts').doc(instructorId).get();
      if (!doc.exists) return null;
      return InstructorDetails(
        name: _combineName(doc.data()!, fallback: 'Unknown Instructor'),
        departmentName: _strOrNull(doc.data()!['departmentName']),
        photoURL: _strOrNull(doc.data()!['photoURL']),
        firstName: _strOrNull(doc.data()!['firstName']) ?? '',
        lastName: _strOrNull(doc.data()!['lastName']) ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  // IMPROVED: Use collection group query for fetching students
  Future<List<SectionStudent>> fetchStudentsForSection(String sectionName) async {
    try {
      final activeIds = await _findActiveAcademicIds();
      if (activeIds == null) {
        return [];
      }

      final termPathPattern = 'academic_years/${activeIds['academicYearId']}/semesters/${activeIds['semesterId']}';

      // Will store unique student IDs from enrolled_students
      final studentIds = <String>{};

      // Use collection group to find sections with matching name
      final sectionQuery = _db.collectionGroup('sections')
          .where('sectionName', isEqualTo: sectionName);

      final sectionSnap = await sectionQuery.get();

      // Filter to sections in the active term
      final validSections = sectionSnap.docs.where((doc) {
        final path = doc.reference.path;
        return path.contains(termPathPattern);
      }).toList();

      // For each valid section, get schedules and enrolled students
      for (final sectionDoc in validSections) {
        final schedulesQuery = sectionDoc.reference.collection('schedules');
        final schedulesSnap = await schedulesQuery.get();

        for (final scheduleDoc in schedulesSnap.docs) {
          final enrolledStudentsQuery = scheduleDoc.reference.collection('enrolled_students');
          final enrolledStudentsSnap = await enrolledStudentsQuery.get();

          // Only consider valid enrollments where studentId matches document ID
          for (final studentDoc in enrolledStudentsSnap.docs) {
            final studentId = studentDoc.data()['studentId']?.toString();
            if (studentId != null && studentId.isNotEmpty) {
              studentIds.add(studentId);
            }
          }
        }
      }

      if (studentIds.isEmpty) {
        return [];
      }

      // Now fetch student details from users collection
      final students = <SectionStudent>[];

      // Process in batches to avoid large IN queries
      const batchSize = 10;
      for (var i = 0; i < studentIds.length; i += batchSize) {
        final endIndex = (i + batchSize < studentIds.length) ? i + batchSize : studentIds.length;
        final batch = studentIds.toList().sublist(i, endIndex);

        final studentsQuery = _db.collection('users').doc('student').collection('accounts')
            .where(FieldPath.documentId, whereIn: batch);

        final studentsSnap = await studentsQuery.get();

        students.addAll(studentsSnap.docs.map((d) => SectionStudent(
          name: _combineName(d.data(), fallback: 'Unknown Student'),
          firstName: _strOrNull(d.data()['firstName']),
          lastName: _strOrNull(d.data()['lastName']),
          photoURL: _strOrNull(d.data()['photoURL']),
        )));
      }

      students.sort((a, b) => (a.lastName ?? '').compareTo(b.lastName ?? ''));
      return students;
    } catch (e) {
      return [];
    }
  }

  Future<List<ScheduleItem>> fetchSchedulesForRoom({required String roomName, required DateTime forDate}) async {
    try {
      final activeIds = await _findActiveAcademicIds();
      if (activeIds == null) {
        return [];
      }

      final dayKey = DateFormat('EEEE').format(forDate).toLowerCase();
      final termPathPattern = 'academic_years/${activeIds['academicYearId']}/semesters/${activeIds['semesterId']}';

      // Use collection group query to find all schedules for this room
      final scheduleQuery = _db.collectionGroup('schedules')
          .where('roomName', isEqualTo: roomName)
          .where('days', arrayContains: dayKey);

      final scheduleSnap = await scheduleQuery.get();

      // Filter to schedules in active term
      final validSchedules = scheduleSnap.docs.where((doc) {
        final path = doc.reference.path;
        return path.contains(termPathPattern);
      }).toList();

      final allSchedules = <ScheduleItem>[];

      // Process each valid schedule
      for (final scheduleDoc in validSchedules) {
        // Get section name from parent
        final sectionRef = scheduleDoc.reference.parent.parent;
        String? sectionName;

        if (sectionRef != null) {
          final sectionDoc = await sectionRef.get();
          sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
        }

        allSchedules.add(_mapSingleDocToScheduleItem(scheduleDoc, sectionName: sectionName));
      }

      // Sort schedules by start time
      allSchedules.sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
      return allSchedules;
    } catch (e) {
      return [];
    }
  }

  // ============================ HELPERS ============================

  List<ScheduleItem> _mapSnapToScheduleItems(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {String? sectionName}) {
    final items = docs.map((d) => _mapSingleDocToScheduleItem(d, sectionName: sectionName)).toList();
    items.sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
    return items;
  }

  ScheduleItem _mapSingleDocToScheduleItem(
      DocumentSnapshot<Map<String, dynamic>> d, {String? sectionName}) {
    final data = d.data()!;
    final start = (data['startTime'] ?? data['timeStart'] ?? '').toString();
    final end = (data['endTime'] ?? data['timeEnd'] ?? '').toString();

    return ScheduleItem(
      subjectName: (data['subjectName'] ?? data['subjectCode'] ?? '').toString(),
      professor: (data['instructorName'] ?? '').toString(),
      startTime: start,
      endTime: end,
      courseName: _strOrNull(data['courseName']),
      sectionName: sectionName,
      room: _strOrNull(data['roomName'] ?? data['room']),
      instructorId: _strOrNull(data['instructorId']),
    );
  }

  String _combineName(Map<String, dynamic> data, {required String fallback}) {
    final firstName = _strOrNull(data['firstName']);
    final lastName = _strOrNull(data['lastName']);
    final combined = [firstName, lastName].where((n) => n != null && n.isNotEmpty).join(' ');
    if (combined.isNotEmpty) return combined;
    final singleName = _strOrNull(data['name']);
    return singleName ?? fallback;
  }


  String _todayDay() {
    return DateFormat('EEEE').format(DateTime.now()).toLowerCase();
  }

  int _parseTimeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    final fmts = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a'];
    for (final f in fmts) { try { final dt = DateFormat(f).parse(timeStr); return dt.hour * 60 + dt.minute; } catch (_) {} }
    return 0;
  }

  String? _strOrNull(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}