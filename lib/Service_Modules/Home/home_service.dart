import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'home_UI.dart'; // for ScheduleItem and other models

class HomeService {
  final FirebaseFirestore _db;
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

  Future<Map<String, String>?> getAcademicIdsFromUser({
    required String role,
    required String uid,
  }) async {
    final user = await fetchUserDetails(role: role, uid: uid);
    if (user == null) return null;

    final academicYearId = _idOf(user['academicYear'] ?? user['academicYearId']);
    final semesterId     = _idOf(user['semester']     ?? user['semesterId']);
    final departmentId   = _idOf(user['department']   ?? user['departmentId']);
    final courseId       = _idOf(user['course']       ?? user['courseId']);
    final yearLevelId    = _idOf(user['yearLevel']    ?? user['yearLevelId']);
    final sectionId      = _idOf(user['section']      ?? user['sectionId']);

    if ([academicYearId, semesterId, departmentId, courseId, yearLevelId, sectionId]
        .any((v) => v == null || v.isEmpty)) {
      return null;
    }

    final sectionPath =
        'academic_years/$academicYearId'
        '/semesters/$semesterId'
        '/departments/$departmentId'
        '/courses/$courseId'
        '/year_levels/$yearLevelId'
        '/sections/$sectionId';

    return {
      'academicYearId': academicYearId!,
      'semesterId': semesterId!,
      'departmentId': departmentId!,
      'courseId': courseId!,
      'yearLevelId': yearLevelId!,
      'sectionId': sectionId!,
      'sectionPath': sectionPath,
      'courseName': _strOrNull(user['courseName']) ?? '',
      'departmentName': _strOrNull(user['departmentName']) ?? '',
      'sectionName': _strOrNull(user['sectionName']) ?? '',
    };
  }

  // ============================ SCHEDULES ============================

  /// Fetches today's schedules for a STUDENT by finding their section.
  Future<List<ScheduleItem>> fetchSchedulesForStudent({
    required String role,
    required String uid,
  }) async {
    debugPrint("[HomeService] Running STUDENT schedule logic.");
    final ids = await getAcademicIdsFromUser(role: role, uid: uid);
    if (ids == null) {
      debugPrint("[HomeService] Student has no academic IDs. Returning empty list.");
      return [];
    }

    final sectionPath = ids['sectionPath']!;
    final sectionName = ids['sectionName']; // Get the section name from the user's data
    final todayKey = _todayDay();

    debugPrint("[HomeService] Fetching schedules for section path: $sectionPath and day: $todayKey");

    try {
      final sectionRef = _db.doc(sectionPath);
      final snap = await sectionRef
          .collection('schedules')
          .where('days', arrayContains: todayKey)
          .get();

      debugPrint("[HomeService] Student query successful. Found ${snap.docs.length} documents.");
      // Pass the known sectionName to the mapping function
      return _mapSnapToScheduleItems(snap.docs, sectionName: sectionName);
    } catch (e, s) {
      debugPrint("[HomeService] CRITICAL ERROR in fetchSchedulesForStudent: $e");
      debugPrint("Stack Trace: $s");
      throw Exception('Failed to load student schedules. Check security rules or path.');
    }
  }

  /// Fetches today's schedules for a TEACHER/HEAD by querying their instructor ID.
  Future<List<ScheduleItem>> fetchSchedulesForTeacher({
    required String teacherUid,
  }) async {
    final todayKey = _todayDay();
    debugPrint("[HomeService] Running STAFF schedule logic.");
    debugPrint("[HomeService] Querying 'schedules' collection group with:");
    debugPrint("  - instructorId: '$teacherUid'");
    debugPrint("  - days (array-contains): '$todayKey'");

    final query = _db
        .collectionGroup('schedules')
        .where('instructorId', isEqualTo: teacherUid)
        .where('days', arrayContains: todayKey);

    try {
      final snap = await query.get();
      debugPrint("[HomeService] Staff query successful. Found ${snap.docs.length} documents.");

      // For teachers, we need to fetch the sectionName from the parent document of each schedule.
      final itemsWithSections = await Future.wait(snap.docs.map((doc) async {
        String? sectionName;
        // The parent of a schedule document is the 'schedules' collection.
        // The parent of that collection is the section document.
        final sectionDocRef = doc.reference.parent.parent;
        if (sectionDocRef != null) {
          final sectionDoc = await sectionDocRef.get();
          if (sectionDoc.exists) {
            sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
          }
        }
        return _mapSingleDocToScheduleItem(doc, sectionName: sectionName);
      }));

      // Sort by start time
      itemsWithSections.sort((a, b) =>
          _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));

      return itemsWithSections;

    } catch (e, s) {
      debugPrint("[HomeService] CRITICAL ERROR in fetchSchedulesForTeacher: $e");
      debugPrint("Stack Trace: $s");
      throw Exception(
          'Failed to load staff schedules. This is often a Firestore Security Rules or Indexing issue.'
      );
    }
  }

  /// SHARED mapping logic for STUDENT queries where sectionName is already known.
  List<ScheduleItem> _mapSnapToScheduleItems(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {String? sectionName}) {
    final items = docs.map((d) => _mapSingleDocToScheduleItem(d, sectionName: sectionName)).toList();

    // Sort by start time
    items.sort((a, b) =>
        _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
    return items;
  }

  /// Maps a SINGLE document to a ScheduleItem.
  ScheduleItem _mapSingleDocToScheduleItem(
      QueryDocumentSnapshot<Map<String, dynamic>> d, {String? sectionName}) {
    final data = d.data();
    final start = (data['startTime'] ?? data['timeStart'] ?? '').toString();
    final end = (data['endTime'] ?? data['timeEnd'] ?? '').toString();

    return ScheduleItem(
      subjectName: (data['subjectName'] ?? data['subjectCode'] ?? '').toString(),
      professor: (data['instructorName'] ?? '').toString(),
      startTime: start,
      endTime: end,
      courseName: _strOrNull(data['courseName']),
      sectionName: sectionName, // Use the passed-in sectionName
      room: _strOrNull(data['roomName'] ?? data['room']),
      instructorId: _strOrNull(data['instructorId']),
    );
  }


  // ===================== Chip-tap Details Fetching =====================

  /// Fetches the details for a given instructor ID.
  Future<InstructorDetails?> fetchInstructorDetails(String instructorId) async {
    try {
      final doc = await _db.collection('users/teacher/accounts').doc(instructorId).get();
      if (!doc.exists) return null;
      final data = doc.data()!;

      final firstName = _strOrNull(data['firstName']) ?? '';
      final lastName = _strOrNull(data['lastName']) ?? '';

      return InstructorDetails(
        name: _combineName(data, fallback: 'Unknown Instructor'),
        departmentName: _strOrNull(data['departmentName']),
        photoURL: _strOrNull(data['photoURL']),
        firstName: firstName,
        lastName: lastName,
      );
    } catch (e) {
      debugPrint("[HomeService] Error fetching instructor details: $e");
      return null;
    }
  }

  /// Fetches all students belonging to a specific section.
  Future<List<SectionStudent>> fetchStudentsForSection(String sectionName) async {
    try {
      // Use a collection group query to find all 'accounts' collections.
      final query = _db
          .collectionGroup('accounts')
          .where('role', isEqualTo: 'Student')
          .where('sectionName', isEqualTo: sectionName);

      final snap = await query.get();

      final students = snap.docs.map((d) {
        final data = d.data();

        final firstName = _strOrNull(data['firstName']) ?? '';
        final lastName = _strOrNull(data['lastName']) ?? '';

        return SectionStudent(
          name: _combineName(data, fallback: 'Unknown Student'),
          firstName: firstName,
          lastName: lastName,
          photoURL: _strOrNull(data['photoURL']),
        );
      }).toList();

      // Handle null last names during sorting.
      students.sort((a, b) => (a.lastName ?? '').compareTo(b.lastName ?? ''));

      return students;

    } catch (e) {
      debugPrint("[HomeService] Error fetching students for section: $e");
      return [];
    }
  }

  /// Fetches all schedules for a specific room for today.
  Future<List<ScheduleItem>> fetchSchedulesForRoom(String roomName) async {
    try {
      final todayKey = _todayDay();
      final query = _db
          .collectionGroup('schedules')
          .where('roomName', isEqualTo: roomName)
          .where('days', arrayContains: todayKey);
      final snap = await query.get();

      // Also fetch sectionName for each schedule
      final itemsWithSections = await Future.wait(snap.docs.map((doc) async {
        String? sectionName;
        final sectionDocRef = doc.reference.parent.parent;
        if (sectionDocRef != null) {
          final sectionDoc = await sectionDocRef.get();
          if (sectionDoc.exists) {
            sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
          }
        }
        return _mapSingleDocToScheduleItem(doc, sectionName: sectionName);
      }));

      itemsWithSections.sort((a, b) =>
          _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));

      return itemsWithSections;

    } catch (e) {
      debugPrint("[HomeService] Error fetching schedules for room: $e");
      return [];
    }
  }

  /*
  // ===================== ANNOUNCEMENTS =====================

  /// Fetches the most recent announcements.
  /// Assumes an 'announcements' collection with a 'createdAt' timestamp field.
  Future<List<AnnouncementItem>> fetchAnnouncements() async {
    try {
      final query = _db
          .collection('announcements')
          .orderBy('createdAt', descending: true) // Get the newest first
          .limit(5); // Limit to 5 announcements

      final snap = await query.get();

      return snap.docs.map((d) {
        final data = d.data();
        final timestamp = data['createdAt'] as Timestamp?;

        return AnnouncementItem(
          title: _strOrNull(data['title']) ?? 'No Title',
          content: _strOrNull(data['content']) ?? '',
          imageUrl: _strOrNull(data['imageUrl']),
          authorName: _strOrNull(data['authorName']),
          createdAt: timestamp?.toDate(),
        );
      }).toList();
    } catch (e) {
      debugPrint("[HomeService] Error fetching announcements: $e");
      return []; // Return an empty list on error
    }
  }
  */


  // ============================ HELPERS ============================

  /// Combines firstName and lastName into a full name.
  String _combineName(Map<String, dynamic> data, {required String fallback}) {
    final firstName = _strOrNull(data['firstName']);
    final lastName = _strOrNull(data['lastName']);

    final combined = [firstName, lastName].where((n) => n != null).join(' ');
    if (combined.isNotEmpty) {
      return combined;
    }

    // Fallback to a single 'name' field if it exists
    final singleName = _strOrNull(data['name']);
    if (singleName != null) {
      return singleName;
    }

    return fallback;
  }

  String? _idOf(dynamic v) {
    if (v == null) return null;
    if (v is DocumentReference) return v.id;
    if (v is String && v.isNotEmpty) {
      return v.contains('/') ? v.split('/').last : v;
    }
    return null;
  }

  String _todayDay() {
    // Uses English day names, matching Firestore data.
    return DateFormat('EEEE').format(DateTime.now()).toLowerCase();
  }

  int _parseTimeToMinutes(String timeStr) {
    final fmts = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a'];
    for (final f in fmts) {
      try {
        final dt = DateFormat(f).parse(timeStr);
        return dt.hour * 60 + dt.minute;
      } catch (_) {}
    }
    return 0;
  }

  String? _strOrNull(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}