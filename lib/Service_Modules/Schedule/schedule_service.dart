import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:project_agila/Service_Modules/Notification/notification_service.dart'; // Import the notification service

// ============================ DATA MODELS (UPDATED) ============================

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

  Session copyWith({
    AttendanceStatus? status,
    DateTime? updatedAt,
  }) {
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
      status: status ?? this.status,
      firstSeen: firstSeen,
      lastSeen: lastSeen,
      source: source,
      academicStatus: academicStatus,
      studentId: studentId,
      updatedAt: updatedAt ?? this.updatedAt,
      studentNo: studentNo,
    );
  }

  Session withStatus(AttendanceStatus newStatus, {DateTime? date}) {
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
      updatedAt: date ?? updatedAt,
      studentNo: studentNo,
    );
  }
}

class StudentAttendanceRecord {
  final String uid;
  final String name;
  final String? studentNumber;
  final AttendanceStatus status;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final String? source;
  final String? photoURL;

  StudentAttendanceRecord({
    required this.uid,
    required this.name,
    this.studentNumber,
    required this.status,
    this.firstSeen,
    this.lastSeen,
    this.source,
    this.photoURL,
  });
}

class SectionStudent {
  final String uid;
  final String name;
  final String? photoURL;
  final String? studentNumber; // Add this property

  SectionStudent({
    required this.uid,
    required this.name,
    this.photoURL,
    this.studentNumber, // Add this parameter
  });
}

class InstructorDetails {
  final String name;
  final String? departmentName;
  final String? photoURL;
  final String? employeeNumber; // Add this field

  InstructorDetails({required this.name, this.departmentName, this.photoURL, this.employeeNumber});
}

class RoomSchedule {
  final String subjectName;
  final String professor;
  final String sectionName;
  final String time;
  RoomSchedule({required this.subjectName, required this.professor, required this.sectionName, required this.time});
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

class AttendanceStatusCounts {
  final int present;
  final int late;
  final int absent;
  final int excused;

  const AttendanceStatusCounts({
    this.present = 0,
    this.late = 0,
    this.absent = 0,
    this.excused = 0,
  });

  int get total => present + late + absent + excused;

  AttendanceStatusCounts copyWith({
    int? present,
    int? late,
    int? absent,
    int? excused,
  }) {
    return AttendanceStatusCounts(
      present: present ?? this.present,
      late: late ?? this.late,
      absent: absent ?? this.absent,
      excused: excused ?? this.excused,
    );
  }
}

// ============================ SERVICE INTERFACE ============================

abstract class ScheduleService {
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

  Future<List<RoomSchedule>> fetchSchedulesForRoom({
    required String roomName,
    required DateTime forDate
  });

  // New method to get sessions by status
  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required String role,
    required AttendanceStatus status,
    required DateTime date,
  });
}

// ============================ FIRESTORE IMPLEMENTATION (UPDATED) ============================

class FirestoreScheduleService implements ScheduleService {
  final FirebaseFirestore _db;
  // Add simple caching to improve performance
  final NotificationService _notificationService = NotificationService(); // Instantiate the service
  final Map<String, ActiveTerm> _termCache = {};

  FirestoreScheduleService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

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

    final isTeacher = role == 'teacher' || role == 'program_head';

    List<Session> allSessions;
    if (isTeacher) {
      allSessions = await _fetchTeacherSchedules(uid: userId, activeTerm: activeTerm);
    } else {
      allSessions = await _fetchStudentSchedules(uid: userId, role: role, activeTerm: activeTerm);
    }

    // Enrich sessions with attendance data
    final enrichedSessionsWithDates = await _enrichSessionsWithAttendanceData(allSessions, userId, role, start, end);

    final results = <DateTime, List<Session>>{};
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final dateOnly = DateTime(d.year, d.month, d.day);
      final sessionsForDay = enrichedSessionsWithDates
          .where((s) => s.updatedAt != null && DateTime(s.updatedAt!.year, s.updatedAt!.month, s.updatedAt!.day) == dateOnly)
          .toList();

      sessionsForDay.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      results[dateOnly] = sessionsForDay;


      // --- NEW: Schedule notifications for today ---
      final today = DateTime.now();
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        _scheduleIncomingClassNotifications(sessionsForDay);
      }
    }
    return (results, activeTerm);
  }

  // --- NEW METHOD TO SCHEDULE NOTIFICATIONS ---
  Future<void> _scheduleIncomingClassNotifications(List<Session> sessions) async {
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

  Future<List<Session>> _fetchTeacherSchedules({required String uid, required ActiveTerm activeTerm}) async {
    final query = _db.collectionGroup('schedules').where('instructorId', isEqualTo: uid);
    final snap = await query.get();
    final activeSchedules = snap.docs.where((doc) {
      final path = doc.reference.path;
      return path.contains(activeTerm.academicYearId) && path.contains(activeTerm.semesterId);
    }).toList();

    final itemsWithData = await Future.wait(activeSchedules.map((doc) async {
      String? sectionName;
      final sectionDocRef = doc.reference.parent.parent;
      if (sectionDocRef != null) {
        final sectionDoc = await sectionDocRef.get();
        sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
      }
      return _mapDocToSessions(doc, sectionName: sectionName);
    }));

    return itemsWithData.expand((sessions) => sessions).toList();
  }

  Future<List<Session>> _fetchStudentSchedules({required String uid, required String role, required ActiveTerm activeTerm}) async {
    final userDetails = await _fetchUserDetails(role: role, uid: uid);
    if (userDetails == null) throw Exception('Could not find your user details.');

    final academicStatus = _strOrNull(userDetails['academicStatus']) ?? 'regular';

    if (academicStatus == 'regular') {
      return _fetchRegularStudentSchedule(userDetails: userDetails, activeTerm: activeTerm);
    } else {
      return _fetchIrregularStudentSchedule(uid: uid, activeTerm: activeTerm);
    }
  }

  Future<List<Session>> _enrichSessionsWithAttendanceData(
      List<Session> sessions,
      String userId,
      String role,
      DateTime start,
      DateTime end,
      ) async {
    final enrichedSessions = <Session>[];
    final scheduleIds = sessions.map((s) => s.id).toSet();

    if (scheduleIds.isEmpty) {
      return [];
    }

    // Create a set of date strings for the given range for efficient lookup.
    final dateStrings = <String>{};
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      dateStrings.add(_formatDateStr(d));
    }

    // Fetch all attendance documents for the relevant schedule IDs.
    // This is now a valid query using 'whereIn' on a single field.
    final allAttendanceDocs = <DocumentSnapshot>[];
    final scheduleIdChunks = _chunk(scheduleIds.toList(), 30);

    for (final idChunk in scheduleIdChunks) {
      if (idChunk.isEmpty) continue;
      final attendanceSessionsSnap = await _db
          .collection('attendance_sessions')
          .where('scheduleId', whereIn: idChunk)
          .get();

      // Filter by date range in Dart to avoid an invalid query.
      for (final doc in attendanceSessionsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateStr = data['dateStr'] as String?;
        if (dateStr != null && dateStrings.contains(dateStr)) {
          allAttendanceDocs.add(doc);
        }
      }
    }

    // Create a lookup map: 'scheduleId-dateStr' -> Document
    final attendanceByScheduleIdAndDate = <String, DocumentSnapshot>{};
    for (final doc in allAttendanceDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final scheduleId = data['scheduleId'] as String?;
      final dateStr = data['dateStr'] as String?;
      if (scheduleId != null && dateStr != null) {
        attendanceByScheduleIdAndDate['$scheduleId-$dateStr'] = doc;
      }
    }

    // Iterate through each day in the range to build the final list of sessions.
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final dateStr = _formatDateStr(d);
      final sessionsForDay = sessions.where((s) => s.weekday == d.weekday).toList();

      for (final session in sessionsForDay) {
        final attendanceSessionDoc = attendanceByScheduleIdAndDate['${session.id}-$dateStr'];

        if (attendanceSessionDoc != null) {
          // An attendance session exists for this day.
          DocumentSnapshot? userAttendanceDoc;
          if (role == 'teacher' || role == 'program_head') {
            userAttendanceDoc = await attendanceSessionDoc.reference.collection('instructor').doc('main').get();
          } else {
            userAttendanceDoc = await attendanceSessionDoc.reference.collection('students').doc(userId).get();
          }

          if (userAttendanceDoc.exists && userAttendanceDoc.data() != null) {
            // User has a record in this session.
            final data = userAttendanceDoc.data() as Map<String, dynamic>;
            enrichedSessions.add(Session(
              id: session.id,
              subject: session.subject,
              section: session.section,
              room: session.room,
              roomType: session.roomType,
              weekday: d.weekday,
              startMinutes: session.startMinutes,
              endMinutes: session.endMinutes,
              colorHex: session.colorHex,
              instructorId: session.instructorId,
              instructorName: session.instructorName,
              status: _parseAttendanceStatus(data['status']),
              firstSeen: _parseDate(data['firstSeen']),
              lastSeen: _parseDate(data['lastSeen']),
              source: _strOrNull(data['source']),
              academicStatus: _strOrNull(data['academicStatus']),
              studentId: userId,
              updatedAt: _parseDate(data['updatedAt']) ?? d,
              studentNo: _strOrNull(data['studentNo']),
            ));
          } else {
            // Session exists, but user has no record.
            final endTime = DateTime(d.year, d.month, d.day, session.endMinutes ~/ 60, session.endMinutes % 60);
            if (DateTime.now().isAfter(endTime)) {
              enrichedSessions.add(session.withStatus(AttendanceStatus.absent, date: d));
            } else {
              enrichedSessions.add(session.withStatus(AttendanceStatus.scheduled, date: d));
            }
          }
        } else {
          // No attendance session was created for this day.
          final endTime = DateTime(d.year, d.month, d.day, session.endMinutes ~/ 60, session.endMinutes % 60);
          if (DateTime.now().isAfter(endTime)) {
            enrichedSessions.add(session.copyWith(status: AttendanceStatus.none, updatedAt: d));
          } else {
            enrichedSessions.add(session.copyWith(status: AttendanceStatus.scheduled, updatedAt: d));
          }
        }
      }
    }
    return enrichedSessions;
  }


  Future<Map<String, dynamic>> fetchSessionAcademicDetails({
    required String scheduleId,
    required ActiveTerm? activeTerm,
  }) async {
    final result = {
      'acadYear': '',
      'semesterName': '',
      'courseName': '',
      'yearLevelName': '',
      'sectionName': '',
    };

    try {

      if (activeTerm == null) {
        return result;
      }

      // Fetch academic year details directly
      final yearDoc = await _db.collection('academic_years').doc(activeTerm.academicYearId).get();
      if (yearDoc.exists && yearDoc.data() != null) {
        final yearData = yearDoc.data()!;
        result['acadYear'] = _strOrNull(yearData['acadYear'] ?? yearData['name']) ?? 'Current Academic Year';
        debugPrint('[PDF] Academic year: ${result['acadYear']}');
      }

      // Fetch semester details
      final semDoc = await _db.collection('academic_years')
          .doc(activeTerm.academicYearId)
          .collection('semesters')
          .doc(activeTerm.semesterId)
          .get();
      if (semDoc.exists && semDoc.data() != null) {
        final semData = semDoc.data()!;
        result['semesterName'] = _strOrNull(semData['semesterName'] ?? semData['name'] ?? semData['title']) ?? 'Current Semester';
        debugPrint('[PDF] Semester name: ${result['semesterName']}');
      }

      // Search for the schedule document to find its path
      final departmentsSnap = await semDoc.reference.collection('departments').get();
      for (final deptDoc in departmentsSnap.docs) {
        final coursesSnap = await deptDoc.reference.collection('courses').get();
        for (final courseDoc in coursesSnap.docs) {
          final yearLevelsSnap = await courseDoc.reference.collection('year_levels').get();
          for (final yearLevelDoc in yearLevelsSnap.docs) {
            final sectionsSnap = await yearLevelDoc.reference.collection('sections').get();
            for (final sectionDoc in sectionsSnap.docs) {
              final scheduleDoc = await sectionDoc.reference.collection('schedules').doc(scheduleId).get();
              if (scheduleDoc.exists) {
                // Found it! Now fill in the details.
                result['courseName'] = _strOrNull(courseDoc.data()['courseName']) ?? '';
                result['yearLevelName'] = _strOrNull(yearLevelDoc.data()['yearLevelName']) ?? '';
                result['sectionName'] = _strOrNull(sectionDoc.data()['sectionName'] ?? sectionDoc.data()['name']) ?? '';
                return result; // Exit once found
              }
            }
          }
        }
      }
      return result;

    } catch (e) {
      return result;
    }
  }

  // Add this method to your FirestoreScheduleService class
  Future<List<StudentAttendanceRecord>> fetchStudentAttendanceForSession({
    required String scheduleId,
    String? dateStr
  }) async {
    try {
      // Use provided date or default to current date
      final actualDateStr = dateStr ?? _formatDateStr(DateTime.now());
      // First, find the attendance session document for this schedule on this date
      final attendanceSessionsQuery = await _db
          .collection('attendance_sessions')
          .where('dateStr', isEqualTo: actualDateStr)
          .where('scheduleId', isEqualTo: scheduleId)
          .limit(1)
          .get();

      if (attendanceSessionsQuery.docs.isEmpty) {
        return [];
      }

      final attendanceSessionDoc = attendanceSessionsQuery.docs.first;

      // Get all students attendance records from this session
      final studentsSnap = await attendanceSessionDoc.reference
          .collection('students')
          .get();


      final attendanceRecords = <StudentAttendanceRecord>[];

      // Process each attendance record
      for (final doc in studentsSnap.docs) {
        try {
          final data = doc.data();
          final studentId = doc.id;
          final status = _parseAttendanceStatus(data['status']);
          final fullName = _strOrNull(data['fullName']) ?? 'Unknown Student';
          final studentNumber = _strOrNull(data['studentNo']);

          attendanceRecords.add(StudentAttendanceRecord(
            uid: studentId,
            name: fullName,
            studentNumber: studentNumber,
            status: status,
            firstSeen: _parseDate(data['firstSeen']),
            lastSeen: _parseDate(data['lastSeen']),
            source: _strOrNull(data['source']),
            photoURL: null, // We'll add photo URLs in a moment
          ));
        } catch (e) {
          debugPrint('[ATTENDANCE] Error processing student attendance record: $e');
        }
      }

      // Enhance records with photo URLs if available
      for (int i = 0; i < attendanceRecords.length; i++) {
        final record = attendanceRecords[i];
        try {
          final studentDoc = await _db
              .collection('users')
              .doc('student')
              .collection('accounts')
              .doc(record.uid)
              .get();

          if (studentDoc.exists && studentDoc.data() != null) {
            final photoURL = _strOrNull(studentDoc.data()!['photoURL']);
            if (photoURL != null) {
              // Create a new record with the photo URL
              attendanceRecords[i] = StudentAttendanceRecord(
                uid: record.uid,
                name: record.name,
                studentNumber: record.studentNumber,
                status: record.status,
                firstSeen: record.firstSeen,
                lastSeen: record.lastSeen,
                source: record.source,
                photoURL: photoURL,
              );
            }
          }
        } catch (e) {
          // Ignore errors fetching photo URL
          debugPrint('[ATTENDANCE] Error fetching photo URL: $e');
        }
      }

      // Sort by name
      attendanceRecords.sort((a, b) => a.name.compareTo(b.name));
      return attendanceRecords;

    } catch (e) {
      return [];
    }
  }

  Future<Map<String, List<StudentAttendanceRecord>>> fetchStudentAttendanceForDateRange({
    required List<String> studentUids,
    required List<String> scheduleIds,
    required DateTime start,
    required DateTime end,
  }) async {
    if (studentUids.isEmpty || scheduleIds.isEmpty) return {};

    final dateStrings = <String>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      dateStrings.add(_formatDateStr(d));
    }

    // Chunk the date strings to avoid Firestore's 30-item limit for 'in' queries
    final dateChunks = _chunk(dateStrings, 30);
    final allAttendanceDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final chunk in dateChunks) {
      if (chunk.isEmpty) continue;
      final attendanceSessionsSnap = await _db
          .collection('attendance_sessions')
          .where('scheduleId', whereIn: scheduleIds)
          .where('dateStr', whereIn: chunk)
          .get();
      allAttendanceDocs.addAll(attendanceSessionsSnap.docs);
    }

    final results = <String, List<StudentAttendanceRecord>>{};
    for (final studentId in studentUids) {
      results[studentId] = [];
    }

    for (final attendanceDoc in allAttendanceDocs) {
      final studentRecordsSnap = await attendanceDoc.reference.collection('students').get();
      for (final studentDoc in studentRecordsSnap.docs) {
        if (results.containsKey(studentDoc.id)) {
          final data = studentDoc.data();
          results[studentDoc.id]!.add(StudentAttendanceRecord(
            uid: studentDoc.id,
            name: _strOrNull(data['fullName']) ?? 'Unknown',
            studentNumber: _strOrNull(data['studentNo']),
            status: _parseAttendanceStatus(data['status']),
            firstSeen: _parseDate(data['firstSeen']),
            lastSeen: _parseDate(data['lastSeen']),
            source: _strOrNull(data['source']),
          ));
        }
      }
    }
    return results;
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

  Future<List<Session>> _fetchRegularStudentSchedule({required Map<String, dynamic> userDetails, required ActiveTerm activeTerm}) async {
    final pathIds = {
      'departmentId': _idOf(userDetails['departmentId']),
      'courseId': _idOf(userDetails['courseId']),
      'yearLevelId': _idOf(userDetails['yearLevelId']),
      'sectionId': _idOf(userDetails['sectionId']),
    };

    if (pathIds.containsValue(null)) {
      throw Exception('Your account is missing required academic information (departmentId, courseId, yearLevelId, or sectionId).');
    }

    final sectionPath = 'academic_years/${activeTerm.academicYearId}/semesters/${activeTerm.semesterId}/departments/${pathIds['departmentId']}/courses/${pathIds['courseId']}/year_levels/${pathIds['yearLevelId']}/sections/${pathIds['sectionId']}';

    final query = _db.doc(sectionPath).collection('schedules');
    final snap = await query.get();

    final sectionName = _strOrNull(userDetails['sectionName']);
    final itemsWithData = snap.docs.map((doc) => _mapDocToSessions(doc, sectionName: sectionName)).toList();
    return itemsWithData.expand((sessions) => sessions).toList();
  }

  Future<List<Session>> _fetchIrregularStudentSchedule({required String uid, required ActiveTerm activeTerm}) async {
    // This logic is copied from the attendance module for completeness.
    final query = _db.collectionGroup('enrolled_students').where(FieldPath.documentId, isEqualTo: uid);
    final enrolledSnap = await query.get();
    if (enrolledSnap.docs.isEmpty) return [];

    final scheduleRefs = enrolledSnap.docs.map((doc) => doc.reference.parent.parent).where((ref) => ref != null).toList();

    final activeSchedules = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for(final ref in scheduleRefs) {
      if(ref!.path.contains(activeTerm.academicYearId) && ref.path.contains(activeTerm.semesterId)) {
        final doc = await ref.get();
        if(doc.exists) activeSchedules.add(doc as QueryDocumentSnapshot<Map<String, dynamic>>);
      }
    }

    final itemsWithData = await Future.wait(activeSchedules.map((doc) async {
      String? sectionName;
      final sectionDocRef = doc.reference.parent.parent;
      if (sectionDocRef != null) {
        final sectionDoc = await sectionDocRef.get();
        sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
      }
      return _mapDocToSessions(doc, sectionName: sectionName);
    }));

    return itemsWithData.expand((sessions) => sessions).toList();
  }

  @override
  Future<List<SectionStudent>> fetchStudentsForSection({
    required String sectionName,
    required String scheduleId
  }) async {

    try {
      // Get the schedule reference - avoid collection group query that was causing issues
      final scheduleSnap = await _db.collectionGroup('schedules')
          .limit(10)
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
        return [];
      }

      // Get enrolled students
      final enrolledStudentsSnap = await scheduleRef.collection('enrolled_students').get();

      if (enrolledStudentsSnap.docs.isEmpty) {
        return [];
      }

      // Process enrolled students
      final students = <SectionStudent>[];

      for (final enrollDoc in enrolledStudentsSnap.docs) {
        try {
          final data = enrollDoc.data();
          final studentIdField = _strOrNull(data['studentId']);

          if (studentIdField == null || studentIdField.isEmpty) {
            continue;
          }

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
                studentNumber: _strOrNull(studentData['studentNumber'] ?? studentData['id']), // Add this line
              ));
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
              studentNumber: _strOrNull(studentData['studentNumber'] ?? studentData['id']), // Add this line
            ));
          }
        } catch (e) {
          debugPrint("[Roster] Error processing student: $e");
        }
      }

      // Sort students by name
      students.sort((a, b) => a.name.compareTo(b.name));
      return students;

    } catch (e) {
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

    final data = doc.data()!;
    final details = InstructorDetails(
      name: _combineName(data, fallback: 'Unknown Instructor'),
      departmentName: _strOrNull(data['departmentName']),
      photoURL: _strOrNull(data['photoURL']),
      employeeNumber: _strOrNull(data['employeeNumber']) ??
          _strOrNull(data['employeeNo']) ??
          _strOrNull(data['staffId']),
    );
    return details;
  }

  @override
  Future<List<RoomSchedule>> fetchSchedulesForRoom({required String roomName, required DateTime forDate}) async {
    // This logic remains the same.
    try {
      final dayKey = DateFormat('EEEE').format(forDate).toLowerCase();

      final query = _db.collectionGroup('schedules')
          .where('roomName', isEqualTo: roomName)
          .where('days', arrayContains: dayKey);

      final snap = await query.get();
      final itemsWithSections = await Future.wait(snap.docs.map((doc) async {
        String? sectionName;
        final sectionDocRef = doc.reference.parent.parent;
        if (sectionDocRef != null) {
          final sectionDoc = await sectionDocRef.get();
          sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
        }
        final data = doc.data();
        final start = (data['startTime'] ?? data['timeStart'] ?? '').toString();
        final end = (data['endTime'] ?? data['timeEnd'] ?? '').toString();

        return RoomSchedule(
          subjectName: (data['subjectName'] ?? 'N/A').toString(),
          professor: (data['instructorName'] ?? 'N/A').toString(),
          sectionName: sectionName ?? 'N/A',
          time: '$start - $end',
        );
      }));
      itemsWithSections.sort((a, b) => a.time.compareTo(b.time));
      return itemsWithSections;
    } catch (e) {
      return [];
    }
  }

  // ============================ HELPERS (UPDATED) ============================

  List<List<T>> _chunk<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }

  String _formatDateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

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
      return AttendanceStatus.scheduled;
    }
    return AttendanceStatus.scheduled;
  }

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

  Future<Map<String, dynamic>?> _fetchUserDetails({required String role, required String uid}) async {
    final snap = await _db.collection('users').doc(role).collection('accounts').doc(uid).get();
    return snap.data();
  }

  List<Session> _mapDocToSessions(QueryDocumentSnapshot<Map<String, dynamic>> d, {String? sectionName}) {
    final data = d.data();
    final daysList = data['days'] as List<dynamic>? ?? [];
    final weekdays = daysList.map((day) => _dayNameToWeekday(day.toString())).where((d) => d != -1).toList();
    final startStr = (data['startTime'] ?? data['timeStart'] ?? '').toString();
    final endStr = (data['endTime'] ?? data['timeEnd'] ?? '').toString();

    // Combine subject code and name
    final subjectCode = _strOrNull(data['subjectCode']);
    final subjectNameStr = _strOrNull(data['subjectName']);
    String displaySubject = subjectNameStr ?? 'No Subject';
    if (subjectCode != null && subjectNameStr != null) {
      displaySubject = '$subjectCode - $subjectNameStr';
    } else if (subjectCode != null) {
      displaySubject = subjectCode;
    }

    return weekdays.map((weekday) {
      return Session(
        id: d.id,
        subject: displaySubject,
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

  String? _idOf(dynamic v) {
    if (v is DocumentReference) return v.id;
    if (v is String && v.isNotEmpty) return v.contains('/') ? v.split('/').last : v;
    return null;
  }

  String? _strOrNull(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  String _combineName(Map<String, dynamic> data, {required String fallback}) {
    final firstName = _strOrNull(data['firstName']);
    final lastName = _strOrNull(data['lastName']);
    final combined = [lastName, firstName].where((n) => n != null && n.isNotEmpty).join(', ');
    if (combined.isNotEmpty) return combined;
    final singleName = _strOrNull(data['name']);
    return singleName ?? fallback;
  }

  int _dayNameToWeekday(String day) {
    final d = day.toLowerCase();
    if (d.startsWith('mon')) return 1; if (d.startsWith('tue')) return 2; if (d.startsWith('wed')) return 3;
    if (d.startsWith('thu')) return 4; if (d.startsWith('fri')) return 5; if (d.startsWith('sat')) return 6;
    if (d.startsWith('sun')) return 7;
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