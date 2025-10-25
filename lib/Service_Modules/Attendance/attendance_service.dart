import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:project_agila/Service_Modules/Notification/notification_service.dart';

// ============================ DATA MODELS ============================

enum AttendanceStatus { scheduled, present, late, absent, excused, none }

class Session {
  final String id;
  final String subject;
  final String section;
  final String room;
  final String roomType;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final int colorHex;
  final String instructorId;
  final String? instructorName;
  final AttendanceStatus status;

  // New fields for detailed attendance data
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final String? source; // "Manual" or "CCTV"
  final String? academicStatus;
  final String? studentId; // UID of the user
  final DateTime? updatedAt;
  final String? studentNo;

  const Session({
    required this.id,
    required this.subject,
    required this.section,
    required this.room,
    required this.roomType,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.colorHex,
    required this.instructorId,
    this.instructorName,
    this.status = AttendanceStatus.scheduled,
    this.firstSeen,
    this.lastSeen,
    this.source,
    this.academicStatus,
    this.studentId,
    this.updatedAt,
    this.studentNo,
  });

  Session withStatus(AttendanceStatus newStatus) {
    return Session(
      id: id,
      subject: subject,
      section: section,
      room: room,
      roomType: roomType,
      weekday: weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      colorHex: colorHex,
      instructorId: instructorId,
      instructorName: instructorName,
      status: newStatus,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
      source: source,
      academicStatus: academicStatus,
      studentId: studentId,
      updatedAt: updatedAt,
      studentNo: studentNo,
    );
  }
}

class SectionStudent {
  final String uid;
  final String name;
  final String? photoURL;
  SectionStudent({required this.uid, required this.name, this.photoURL});
}

class InstructorDetails {
  final String name;
  final String? departmentName;
  final String? photoURL;
  InstructorDetails({required this.name, this.departmentName, this.photoURL});
}

class ActiveTerm {
  final String academicYearId;
  final String semesterId;
  final DateTime startDate;
  final DateTime endDate;
  ActiveTerm({
    required this.academicYearId,
    required this.semesterId,
    required this.startDate,
    required this.endDate,
  });
}


// ============================ SERVICE INTERFACE ============================

abstract class AttendanceService {
  Future<(Map<DateTime, List<Session>>, ActiveTerm?)> getSessionsForRange({
    required String userId,
    required String role,
    required DateTime start,
    required DateTime end,
  });

  Future<List<SectionStudent>> fetchStudentsForSection({
    required String sectionName,
    required String scheduleId,
  });

  Future<InstructorDetails?> fetchInstructorDetails({
    required String instructorId
  });

  // New method to get attendance records by status
  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required String role,
    required AttendanceStatus status,
    required DateTime date,
  });
}

// ============================ FIRESTORE IMPLEMENTATION ============================

class FirestoreAttendanceService implements AttendanceService {
  final FirebaseFirestore _db;
  // Add simple caching to improve performance
  final NotificationService _notificationService = NotificationService(); // Instantiate the service
  final Map<String, ActiveTerm> _termCache = {};

  FirestoreAttendanceService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  // --- Main Data Fetching ---
  @override
  Future<(Map<DateTime, List<Session>>, ActiveTerm?)> getSessionsForRange({
    required String userId,
    required String role,
    required DateTime start,
    required DateTime end,
  }) async {
    final activeTerm = await _findActiveTerm();
    if (activeTerm == null) {
      throw Exception('No active academic term is set. Please contact an administrator.');
    }

    // Use the collection group query approach for fetching schedules
    List<Session> allSessions = await _fetchStudentSchedulesWithCollectionGroup(
        uid: userId,
        activeTerm: activeTerm
    );

    // Fetch attendance data for these sessions
    allSessions = await _enrichSessionsWithAttendanceData(allSessions, userId, start, end);

    final results = <DateTime, List<Session>>{};
    final sessionsByWeekday = <int, List<Session>>{};
    for (final session in allSessions) {
      sessionsByWeekday.putIfAbsent(session.weekday, () => []).add(session);
    }
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final sessionsForDay = sessionsByWeekday[d.weekday] ?? [];
      sessionsForDay.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      results[d] = sessionsForDay;

      // --- NEW: Schedule notifications for today ---
      final today = DateTime.now();
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        _scheduleIncomingClassNotifications(sessionsForDay);
      }
      // --- End new code ---
    }
    return (results, activeTerm);
  }

  // --- NEW METHOD TO SCHEDULE NOTIFICATIONS ---
  Future<void> _scheduleIncomingClassNotifications(List<Session> sessions) async {
    debugPrint('[NOTIFICATION] Checking ${sessions.length} sessions for student to schedule notifications.');
    final now = DateTime.now();

    for (final session in sessions) {
      final startTimeMinutes = session.startMinutes;
      final classDateTime = DateTime(now.year, now.month, now.day, startTimeMinutes ~/ 60, startTimeMinutes % 60);

      // Schedule notification 15 minutes before the class starts
      final notificationTime = classDateTime.subtract(const Duration(minutes: 15));

      // Only schedule if the notification time is in the future
      if (notificationTime.isAfter(now)) {
        await _notificationService.scheduleNotification(
          id: session.id.hashCode, // Use a unique ID for each notification
          title: 'Upcoming Class',
          body: 'Your class "${session.subject}" starts in 15 minutes.',
          scheduledTime: notificationTime,
        );
      }
    }
  }


  Future<List<Session>> _enrichSessionsWithAttendanceData(
      List<Session> sessions,
      String userId,
      DateTime start,
      DateTime end
      ) async {
    try {
      // Format dates for query
      final List<String> dateStrings = [];
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        dateStrings.add(_formatDateStr(d));
      }

      debugPrint('[ATTENDANCE DEBUG] ======================================');
      debugPrint('[ATTENDANCE DEBUG] CURRENT USER: $userId');
      debugPrint('[ATTENDANCE DEBUG] Current date: ${_formatDateStr(DateTime.now())}');
      debugPrint('[ATTENDANCE DEBUG] Fetching attendance for dates: $dateStrings');
      debugPrint('[ATTENDANCE DEBUG] Total sessions to check: ${sessions.length}');

      // Create a set of valid scheduleIds that the student is enrolled in
      final enrolledScheduleIds = sessions.map((s) => s.id).toSet();
      debugPrint('[ATTENDANCE DEBUG] Enrolled schedule IDs: $enrolledScheduleIds');

      // Map to store fetched attendance sessions by scheduleId for quick lookup
      final attendanceBySubjectId = <String, List<DocumentSnapshot<Map<String, dynamic>>>>{};
      int totalAttendanceRecords = 0;
      final now = DateTime.now(); // Get current time for absence check

      // Query attendance sessions for each date in range
      for (final dateStr in dateStrings) {
        try {
          debugPrint('[ATTENDANCE DEBUG] Querying collection "attendance_sessions" with dateStr = $dateStr');

          final snapshot = await _db
              .collection('attendance_sessions')
              .where('dateStr', isEqualTo: dateStr)
              .get();

          debugPrint('[ATTENDANCE DEBUG] Found ${snapshot.docs.length} attendance sessions for date $dateStr');
          totalAttendanceRecords += snapshot.docs.length;

          // Check each session for this user's attendance
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final subjectName = _strOrNull(data['subjectName']) ?? 'Unknown Subject';
            final scheduleId = _strOrNull(data['scheduleId']);

            debugPrint('[USER CHECK] Checking for user $userId in session: $subjectName');

            try {
              // Store the attendance session document regardless of whether the student has a record
              // We'll use this to mark absences for any session that has ended
              if (scheduleId != null && enrolledScheduleIds.contains(scheduleId)) {
                attendanceBySubjectId.putIfAbsent(scheduleId, () => []).add(doc);
                debugPrint('[ATTENDANCE DEBUG] Added attendance session: $subjectName (ID: $scheduleId) - Student enrolled');
              }

              // Check if student already has an attendance record
              final userAttendanceRef = doc.reference.collection('students').doc(userId);
              final userAttendanceDoc = await userAttendanceRef.get();

              if (userAttendanceDoc.exists) {
                final userData = userAttendanceDoc.data();
                debugPrint('[USER CHECK] ✅ FOUND ATTENDANCE RECORD!');
                debugPrint('[USER CHECK] Path: ${userAttendanceRef.path}');
                debugPrint('[USER CHECK] Status: ${userData?['status'] ?? 'N/A'}');
              } else {
                debugPrint('[USER CHECK] ❌ No attendance record found for this session');
              }
            } catch (e) {
              debugPrint('[USER CHECK] Error checking attendance: $e');
            }
          }
        } catch (e) {
          debugPrint('[ATTENDANCE DEBUG] Error fetching attendance for date $dateStr: $e');
        }
      }

      // Debug output of found sessions
      debugPrint('[ATTENDANCE DEBUG] Found $totalAttendanceRecords total attendance records');
      debugPrint('[ATTENDANCE DEBUG] Attendance data found for enrolled subjects: ${attendanceBySubjectId.keys.join(', ')}');

      // Process each session and find matching attendance data
      final enrichedSessions = <Session>[];
      int matchesFound = 0;

      for (final session in sessions) {
        var enrichedSession = session;
        final matchingAttendanceDocs = attendanceBySubjectId[session.id] ?? [];
        bool foundAttendanceRecord = false;

        debugPrint('[ATTENDANCE DEBUG] Checking session: ${session.subject} (ID: ${session.id})');
        debugPrint('[ATTENDANCE DEBUG] Found ${matchingAttendanceDocs.length} matching attendance docs');

        for (final doc in matchingAttendanceDocs) {
          try {
            debugPrint('[ATTENDANCE DEBUG] Checking attendance doc ${doc.id} for student $userId');

            // Get the student's attendance record
            final studentRef = doc.reference.collection('students').doc(userId);
            debugPrint('[ATTENDANCE DEBUG] Looking up: ${studentRef.path}');

            final studentAttendanceDoc = await studentRef.get();

            if (studentAttendanceDoc.exists && studentAttendanceDoc.data() != null) {
              debugPrint('[ATTENDANCE DEBUG] ✅ Found student attendance record!');
              final attendanceData = studentAttendanceDoc.data()!;
              foundAttendanceRecord = true;

              final statusValue = attendanceData['status'];
              debugPrint('[ATTENDANCE DEBUG] Status: $statusValue');

              // Update the session with attendance data
              final status = _parseAttendanceStatus(statusValue);
              enrichedSession = Session(
                id: session.id,
                subject: session.subject,
                section: session.section,
                room: session.room,
                roomType: session.roomType,
                weekday: session.weekday,
                startMinutes: session.startMinutes,
                endMinutes: session.endMinutes,
                colorHex: session.colorHex,
                instructorId: session.instructorId,
                instructorName: session.instructorName,

                status: status,
                firstSeen: _parseDate(attendanceData['firstSeen']),
                lastSeen: _parseDate(attendanceData['lastSeen']),
                source: session.source,
                academicStatus: _strOrNull(attendanceData['academicStatus']),
                studentId: userId,
                updatedAt: _parseDate(attendanceData['updatedAt']),
                studentNo: _strOrNull(attendanceData['studentNo']),
              );

              matchesFound++;
              break;
            } else {
              debugPrint('[ATTENDANCE DEBUG] ❌ Student record not found in attendance session');
            }
          } catch (e) {
            debugPrint('[ATTENDANCE DEBUG] Error processing attendance for session ${session.id}: $e');
          }
        }

        // NEW: Check if session is past but no attendance session was created
        if (!foundAttendanceRecord && matchingAttendanceDocs.isEmpty) {
          try {
            // Find the date of the session in the queried range
            DateTime? sessionDate;
            for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
              if (d.weekday == session.weekday) {
                sessionDate = d;
                break;
              }
            }

            if (sessionDate != null) {
              // Calculate session end time
              final endTimeMinutes = session.endMinutes;
              final endHour = endTimeMinutes ~/ 60;
              final endMinute = endTimeMinutes % 60;

              final sessionEndTime = DateTime(
                  sessionDate.year,
                  sessionDate.month,
                  sessionDate.day,
                  endHour,
                  endMinute
              );

              debugPrint('[ATTENDANCE DEBUG] Session end time with no attendance session: $sessionEndTime, Current time: $now');

              // If session end time has passed and no attendance session was created
              if (now.isAfter(sessionEndTime)) {
                debugPrint('[ATTENDANCE DEBUG] ⚠️ Session has ended with no attendance session created.');

                // Update the session status to show it's done but had no attendance tracking
                enrichedSession = Session(
                  id: session.id,
                  subject: session.subject,
                  section: session.section,
                  room: session.room,
                  roomType: session.roomType,
                  weekday: session.weekday,
                  startMinutes: session.startMinutes,
                  endMinutes: session.endMinutes,
                  colorHex: session.colorHex,
                  instructorId: session.instructorId,
                  instructorName: session.instructorName,
                  status: AttendanceStatus.none,
                  source: "No attendance session created",
                  updatedAt: now,
                  studentId: userId,
                );

                matchesFound++;
              }
            }
          } catch (e) {
            debugPrint('[ATTENDANCE DEBUG] Error checking for past session with no attendance: $e');
          }
        }

        enrichedSessions.add(enrichedSession);
      }
      debugPrint('[ATTENDANCE DEBUG] Enrichment complete. Found attendance data for $matchesFound out of ${sessions.length} sessions');
      debugPrint('[USER CHECK] SUMMARY: Found attendance data for $matchesFound out of ${sessions.length} sessions');
      debugPrint('[ATTENDANCE DEBUG] ======================================');

      return enrichedSessions;
    } catch (e) {
      debugPrint('[ATTENDANCE DEBUG] Error enriching sessions with attendance data: $e');
      return sessions;
    }
  }

// Helper method to determine the actual date for a session based on weekday

  String _formatDateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // NEW HELPER FUNCTION
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      // It's a Firestore Timestamp, convert it
      return value.toDate();
    }
    if (value is String && value.isNotEmpty) {
      // It's a String, parse it
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint("Failed to parse date string: $value");
        return null;
      }
    }
    // Not a type we recognize
    return null;
  }

  AttendanceStatus _parseAttendanceStatus(dynamic statusValue) {
    if (statusValue == null) return AttendanceStatus.scheduled;

    final rawValue = statusValue.toString();
    final status = rawValue.toLowerCase().trim();

    debugPrint('[STATUS PARSER] Raw status value: "$rawValue"');
    debugPrint('[STATUS PARSER] Lowercase status: "$status"');

    // First handle direct lowercase comparisons
    if (status == 'present') return AttendanceStatus.present;
    if (status == 'late') return AttendanceStatus.late;
    if (status == 'absent') return AttendanceStatus.absent;
    if (status == 'excused') return AttendanceStatus.excused;

    // Then handle partial matches
    if (status.contains('present')) return AttendanceStatus.present;
    if (status.contains('late')) return AttendanceStatus.late;
    if (status.contains('absent')) return AttendanceStatus.absent;
    if (status.contains('excused')) return AttendanceStatus.excused;

    // Special handling for ongoing status
    if (status == 'ongoing') {
      debugPrint('[STATUS PARSER] Found ongoing status - treating as scheduled');
      return AttendanceStatus.scheduled;
    }

    debugPrint('[STATUS PARSER] ⚠️ UNRECOGNIZED STATUS: "$rawValue" - defaulting to scheduled');
    return AttendanceStatus.scheduled;
  }


  @override
  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required String role,
    required AttendanceStatus status,
    required DateTime date,
  }) async {
    try {
      // First, get all sessions for the day
      final (sessionsByDate, _) = await getSessionsForRange(
        userId: userId,
        role: role,
        start: date,
        end: date,
      );

      // Filter sessions by the requested status
      final allSessions = sessionsByDate[date] ?? [];
      return allSessions.where((session) => session.status == status).toList();
    } catch (e) {
      debugPrint('Error fetching sessions by status: $e');
      return [];
    }
  }

  Future<List<Session>> _fetchStudentSchedulesWithCollectionGroup({
    required String uid,
    required ActiveTerm activeTerm
  }) async {
    final enrolledSessions = <Session>[];
    // First, get the student document to retrieve their id field
    final studentDoc = await _db.collection('users').doc('student').collection('accounts').doc(uid).get();
    if (!studentDoc.exists) {
      debugPrint("[AttendanceService] Student document not found: $uid");
      return [];
    }
    // Get the actual id field from the document
    final studentIdField = _strOrNull(studentDoc.data()?['userId']) ?? _strOrNull(studentDoc.data()?['id']);

    if (studentIdField == null) {
      debugPrint("[AttendanceService] Student document missing id field: $uid");
      return [];
    }
    // Create path patterns for filtering
    final termPathPattern = 'academic_years/${activeTerm.academicYearId}/semesters/${activeTerm.semesterId}';
    final schedulesPattern = '/schedules/';

    try {
      // Query for enrollments where studentId matches the id field from the student document
      final enrollmentsQuery = _db.collectionGroup('enrolled_students')
          .where('studentId', isEqualTo: studentIdField);

      final enrollmentsSnapshot = await enrollmentsQuery.get();
      // Filter by path to ensure we only get enrollments from the active term
      final validEnrollments = enrollmentsSnapshot.docs.where((doc) {
        final path = doc.reference.path;
        return path.contains(termPathPattern) && path.contains(schedulesPattern);
      }).toList();
      // Process each valid enrollment (remaining implementation unchanged)
      final futures = validEnrollments.map((doc) async {
        // Get the parent schedule
        final scheduleRef = doc.reference.parent.parent;
        if (scheduleRef == null) return <Session>[];

        final scheduleDoc = await scheduleRef.get();
        if (!scheduleDoc.exists) return <Session>[];

        // Get section info
        final sectionRef = scheduleRef.parent.parent;
        String? sectionName;

        if (sectionRef != null) {
          final sectionDoc = await sectionRef.get();
          sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
        }
        // Map to sessions
        return _mapDocToSessions2(scheduleDoc, sectionName: sectionName);
      });
      // Wait for all processing to complete
      final results = await Future.wait(futures);
      // Combine all sessions
      for (final sessions in results) {
        enrolledSessions.addAll(sessions);
      }
    } catch (e) {
      debugPrint("[AttendanceService] Error fetching student schedules: $e");
    }
    return enrolledSessions;
  }

  // --- Detail Panel Fetching ---

  @override
  Future<List<SectionStudent>> fetchStudentsForSection({
    required String sectionName,
    required String scheduleId
  }) async {
    debugPrint("[Roster] Fetching students for section $sectionName, schedule $scheduleId");

    try {
      // Get the schedule reference - avoid collection group query that was causing issues
      final scheduleSnap = await _db.collectionGroup('schedules')
          .limit(10) // Limit the number of results for performance
          .get();

      DocumentReference? scheduleRef;

      // Find the schedule with matching ID
      for (final doc in scheduleSnap.docs) {
        if (doc.id == scheduleId) {
          scheduleRef = doc.reference;
          break;
        }
      }

      if (scheduleRef == null) {
        debugPrint("[Roster] Schedule not found with ID: $scheduleId");
        return [];
      }

      // Get enrolled students
      final enrolledStudentsSnap = await scheduleRef.collection('enrolled_students').get();

      if (enrolledStudentsSnap.docs.isEmpty) {
        debugPrint("[Roster] No students enrolled in this section");
        return [];
      }

      debugPrint("[Roster] Found ${enrolledStudentsSnap.docs.length} enrollment records");

      // Process enrolled students
      final students = <SectionStudent>[];

      for (final enrollDoc in enrolledStudentsSnap.docs) {
        try {
          // Properly cast the document data to Map<String, dynamic>
          final data = enrollDoc.data();
          final studentIdField = _strOrNull(data['studentId']);

          if (studentIdField == null || studentIdField.isEmpty) {
            debugPrint("[Roster] Missing studentId in enrollment doc");
            continue;
          }

          debugPrint("[Roster] Looking up student with ID: $studentIdField");

          // Try to find student by ID
          QuerySnapshot<Map<String, dynamic>> studentQuery;

          // First try 'id' field
          studentQuery = await _db.collection('users')
              .doc('student')
              .collection('accounts')
              .where('id', isEqualTo: studentIdField)
              .limit(1)
              .get();

          if (studentQuery.docs.isEmpty) {
            // Then try 'userId' field
            studentQuery = await _db.collection('users')
                .doc('student')
                .collection('accounts')
                .where('userId', isEqualTo: studentIdField)
                .limit(1)
                .get();
          }

          if (studentQuery.docs.isEmpty) {
            // If still not found, try direct document lookup using the enrollment doc ID
            final directLookup = await _db.collection('users')
                .doc('student')
                .collection('accounts')
                .doc(enrollDoc.id)
                .get();

            if (directLookup.exists) {
              final studentData = directLookup.data() as Map<String, dynamic>;
              students.add(SectionStudent(
                uid: directLookup.id,
                name: _combineName(studentData, fallback: 'Unknown Student'),
                photoURL: _strOrNull(studentData['photoURL']),
              ));
              debugPrint("[Roster] Added student via direct lookup: ${directLookup.id}");
            } else {
              debugPrint("[Roster] Student not found for ID: $studentIdField");
            }
          } else {
            // Student found via query
            final studentDoc = studentQuery.docs.first;
            final studentData = studentDoc.data();
            students.add(SectionStudent(
              uid: studentDoc.id,
              name: _combineName(studentData, fallback: 'Unknown Student'),
              photoURL: _strOrNull(studentData['photoURL']),
            ));
            debugPrint("[Roster] Added student: ${studentDoc.id}");
          }
        } catch (e) {
          debugPrint("[Roster] Error processing student: $e");
        }
      }

      // Sort students by name
      students.sort((a, b) => a.name.compareTo(b.name));
      debugPrint("[Roster] Found ${students.length} students");
      return students;

    } catch (e) {
      debugPrint("[Roster] Error fetching students: $e");
      return [];
    }
  }

  @override
  Future<InstructorDetails?> fetchInstructorDetails({required String instructorId}) async {
    if (instructorId.trim().isEmpty) {
      return null;
    }
    final path = 'users/teacher/accounts';
    final docRef = _db.collection(path).doc(instructorId);
    final doc = await docRef.get();
    if (!doc.exists) {
      return null;
    }
    final details = InstructorDetails(
      name: _combineName(doc.data()!, fallback: 'Unknown Instructor'),
      departmentName: _strOrNull(doc.data()!['departmentName']),
      photoURL: _strOrNull(doc.data()!['photoURL']),
    );
    return details;
  }

  // --- Internal Helpers ---
  Future<ActiveTerm?> _findActiveTerm() async {
    // Check cache first
    const cacheKey = 'activeTerm';
    if (_termCache.containsKey(cacheKey)) {
      return _termCache[cacheKey];
    }

    // Fetch from Firestore if not in cache
    final yearSnap = await _db.collection('academic_years').where('status', isEqualTo: 'Active').limit(1).get();
    if (yearSnap.docs.isEmpty) return null;

    final yearDoc = yearSnap.docs.first;
    final semSnap = await yearDoc.reference.collection('semesters').where('status', isEqualTo: 'Active').limit(1).get();
    if (semSnap.docs.isEmpty) return null;

    final semDoc = semSnap.docs.first;
    final semData = semDoc.data();

    final startDate = _parseDate(semData['startDate']) ?? DateTime.now();
    final endDate = _parseDate(semData['endDate']) ?? DateTime.now().add(const Duration(days: 120));

    // final startDateString = semData['startDate'] as String?;
    // final endDateString = semData['endDate'] as String?;
    // final startDate = (startDateString != null && startDateString.isNotEmpty) ? DateTime.parse(startDateString) : DateTime.now();
    // final endDate = (endDateString != null && endDateString.isNotEmpty) ? DateTime.parse(endDateString) : DateTime.now().add(const Duration(days: 120));

    final term = ActiveTerm(
        academicYearId: yearDoc.id,
        semesterId: semDoc.id,
        startDate: startDate,
        endDate: endDate
    );

    // Store in cache
    _termCache[cacheKey] = term;
    return term;
  }

  String _formatSubjectDisplay(Map<String, dynamic> data) {
    final code = _strOrNull(data['subjectCode']);
    final name = _strOrNull(data['subjectName']);

    if (code != null && name != null) {
      return '$code - $name';
    }
    return name ?? code ?? 'No Subject';
  }

  // Helper for mapping regular DocumentSnapshot to Sessions
  List<Session> _mapDocToSessions2(DocumentSnapshot<Map<String, dynamic>> d, {String? sectionName}) {
    final data = d.data() ?? {};
    final daysList = data['days'] as List<dynamic>? ?? [];
    final weekdays = daysList.map((day) => _dayNameToWeekday(day.toString())).where((d) => d != -1).toList();
    final startStr = (data['startTime'] ?? data['timeStart'] ?? '').toString();
    final endStr = (data['endTime'] ?? data['timeEnd'] ?? '').toString();
    return weekdays.map((weekday) {
      return Session(
        id: d.id,
        subject: _formatSubjectDisplay(data),
        section: sectionName ?? 'No Section',
        room: _strOrNull(data['roomName'] ?? data['room']) ?? 'N/A',
        roomType: (data['roomType'] as String?)?.toUpperCase() ?? 'LECTURE',
        weekday: weekday,
        startMinutes: _parseTimeToMinutes(startStr),
        endMinutes: _parseTimeToMinutes(endStr),
        colorHex: _parseColorHex(data['color']),
        instructorId: (data['instructorId'] ?? '').toString(),
        instructorName: (data['instructorName'] ?? 'N/A').toString(),
      );
    }).toList();
  }

  String? _strOrNull(dynamic v) => (v ?? '').toString().trim().isEmpty ? null : v.toString().trim();

  String _combineName(Map<String, dynamic> data, {required String fallback}) {
    final f = _strOrNull(data['firstName']);
    final l = _strOrNull(data['lastName']);
    final combined = [l, f].where((n) => n != null).join(', ');
    return combined.isNotEmpty ? combined : (_strOrNull(data['name']) ?? fallback);
  }

  int _dayNameToWeekday(String day) {
    final d = day.toLowerCase();
    if (d.startsWith('mon')) return 1; if (d.startsWith('tue')) return 2; if (d.startsWith('wed')) return 3;
    if (d.startsWith('thu')) return 4; if (d.startsWith('fri')) return 5;
    if (d.startsWith('sat')) return 6; if (d.startsWith('sun')) return 7;
    return -1;
  }

  int _parseTimeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    final fmts = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a'];
    for (final f in fmts) { try { final dt = DateFormat(f).parse(timeStr); return dt.hour * 60 + dt.minute; } catch (_) {} }
    return 0;
  }

  int _parseColorHex(dynamic colorValue) {
    const defaultColor = 0xFF6CA9FF;
    if (colorValue is int) return colorValue;
    if (colorValue is String) {
      try {
        final hex = colorValue.toUpperCase().replaceFirst('#', '').replaceFirst('0X', '');
        if (hex.length == 6) return int.parse('FF$hex', radix: 16);
        if (hex.length == 8) return int.parse(hex, radix: 16);
      } catch (_) {}
    }
    return defaultColor;
  }
}