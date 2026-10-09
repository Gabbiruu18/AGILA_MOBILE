import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:project_agila/Service_Modules/Notification/notification_service.dart';

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

  Future<List<Session>> getSessionsByStatus({
    required String userId,
    required String role,
    required AttendanceStatus status,
    required DateTime date,
  });
}

class FirestoreAttendanceService implements AttendanceService {
  final FirebaseFirestore _db;
  final NotificationService _notificationService = NotificationService();
  final Map<String, ActiveTerm> _termCache = {};

  FirestoreAttendanceService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

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

    List<Session> allSessions = await _fetchStudentSchedulesWithCollectionGroup(
        uid: userId,
        activeTerm: activeTerm
    );

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
      final today = DateTime.now();
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        _scheduleIncomingClassNotifications(sessionsForDay);
      }
    }
    return (results, activeTerm);
  }

  Future<void> _scheduleIncomingClassNotifications(List<Session> sessions) async {
    debugPrint('[NOTIFICATION] Checking ${sessions.length} sessions for student to schedule notifications.');
    final now = DateTime.now();

    for (final session in sessions) {
      final startTimeMinutes = session.startMinutes;
      final classDateTime = DateTime(now.year, now.month, now.day, startTimeMinutes ~/ 60, startTimeMinutes % 60);
      final notificationTime = classDateTime.subtract(const Duration(minutes: 15));
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
      final List<String> dateStrings = [];
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        dateStrings.add(_formatDateStr(d));
      }

      final enrolledScheduleIds = sessions.map((s) => s.id).toSet();

      final attendanceBySubjectId = <String, List<DocumentSnapshot<Map<String, dynamic>>>>{};
      int totalAttendanceRecords = 0;
      final now = DateTime.now();
      for (final dateStr in dateStrings) {
        try {

          final snapshot = await _db
              .collection('attendance_sessions')
              .where('dateStr', isEqualTo: dateStr)
              .get();
          totalAttendanceRecords += snapshot.docs.length;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final subjectName = _strOrNull(data['subjectName']) ?? 'Unknown Subject';
            final scheduleId = _strOrNull(data['scheduleId']);


            try {
              if (scheduleId != null && enrolledScheduleIds.contains(scheduleId)) {
                attendanceBySubjectId.putIfAbsent(scheduleId, () => []).add(doc);
              }
              final userAttendanceRef = doc.reference.collection('students').doc(userId);
              final userAttendanceDoc = await userAttendanceRef.get();

              if (userAttendanceDoc.exists) {
                final userData = userAttendanceDoc.data();
              } else {
              }
            } catch (e) {
              debugPrint('[USER CHECK] Error checking attendance: $e');
            }
          }
        } catch (e) {
          debugPrint('[ATTENDANCE DEBUG] Error fetching attendance for date $dateStr: $e');
        }
      }

      final enrichedSessions = <Session>[];
      int matchesFound = 0;

      for (final session in sessions) {
        var enrichedSession = session;
        final matchingAttendanceDocs = attendanceBySubjectId[session.id] ?? [];
        bool foundAttendanceRecord = false;

        for (final doc in matchingAttendanceDocs) {
          try {

            final studentRef = doc.reference.collection('students').doc(userId);
            final studentAttendanceDoc = await studentRef.get();

            if (studentAttendanceDoc.exists && studentAttendanceDoc.data() != null) {

              final attendanceData = studentAttendanceDoc.data()!;
              foundAttendanceRecord = true;
              final statusValue = attendanceData['status'];
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
              debugPrint('[ATTENDANCE DEBUG] Student record not found in attendance session');
            }
          } catch (e) {
            debugPrint('[ATTENDANCE DEBUG] Error processing attendance for session ${session.id}: $e');
          }
        }

        if (!foundAttendanceRecord && matchingAttendanceDocs.isEmpty) {
          try {
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

              // If session end time has passed and no attendance session was created
              if (now.isAfter(sessionEndTime)) {

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
      return enrichedSessions;
    } catch (e) {
      debugPrint('[ATTENDANCE DEBUG] Error enriching sessions with attendance data: $e');
      return sessions;
    }
  }


  String _formatDateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint("Failed to parse date string: $value");
        return null;
      }
    }
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

    if (status == 'ongoing') {
      return AttendanceStatus.scheduled;
    }
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
      final (sessionsByDate, _) = await getSessionsForRange(
        userId: userId,
        role: role,
        start: date,
        end: date,
      );

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
    final studentDoc = await _db.collection('users').doc('student').collection('accounts').doc(uid).get();
    if (!studentDoc.exists) {
      return [];
    }
    final studentIdField = _strOrNull(studentDoc.data()?['userId']) ?? _strOrNull(studentDoc.data()?['id']);

    if (studentIdField == null) {
      return [];
    }
    final termPathPattern = 'academic_years/${activeTerm.academicYearId}/semesters/${activeTerm.semesterId}';
    final schedulesPattern = '/schedules/';

    try {
      final enrollmentsQuery = _db.collectionGroup('enrolled_students')
          .where('studentId', isEqualTo: studentIdField);

      final enrollmentsSnapshot = await enrollmentsQuery.get();

      final validEnrollments = enrollmentsSnapshot.docs.where((doc) {
        final path = doc.reference.path;
        return path.contains(termPathPattern) && path.contains(schedulesPattern);
      }).toList();
      final futures = validEnrollments.map((doc) async {

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


  @override
  Future<List<SectionStudent>> fetchStudentsForSection({
    required String sectionName,
    required String scheduleId
  }) async {

    try {
      final scheduleSnap = await _db.collectionGroup('schedules')
          .limit(10) // Limit the number of results for performance
          .get();

      DocumentReference? scheduleRef;
      for (final doc in scheduleSnap.docs) {
        if (doc.id == scheduleId) {
          scheduleRef = doc.reference;
          break;
        }
      }

      if (scheduleRef == null) {
        return [];
      }

      final enrolledStudentsSnap = await scheduleRef.collection('enrolled_students').get();

      if (enrolledStudentsSnap.docs.isEmpty) {
        return [];
      }

      final students = <SectionStudent>[];

      for (final enrollDoc in enrolledStudentsSnap.docs) {
        try {
          final data = enrollDoc.data();
          final studentIdField = _strOrNull(data['studentId']);

          if (studentIdField == null || studentIdField.isEmpty) {
            continue;
          }


          QuerySnapshot<Map<String, dynamic>> studentQuery;
          studentQuery = await _db.collection('users')
              .doc('student')
              .collection('accounts')
              .where('id', isEqualTo: studentIdField)
              .limit(1)
              .get();

          if (studentQuery.docs.isEmpty) {
            studentQuery = await _db.collection('users')
                .doc('student')
                .collection('accounts')
                .where('userId', isEqualTo: studentIdField)
                .limit(1)
                .get();
          }

          if (studentQuery.docs.isEmpty) {
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
            }

          } else {
            final studentDoc = studentQuery.docs.first;
            final studentData = studentDoc.data();
            students.add(SectionStudent(
              uid: studentDoc.id,
              name: _combineName(studentData, fallback: 'Unknown Student'),
              photoURL: _strOrNull(studentData['photoURL']),
            ));
          }
        } catch (e) {
          debugPrint("[Roster] Error processing student: $e");
        }
      }

      students.sort((a, b) => a.name.compareTo(b.name));
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

  Future<ActiveTerm?> _findActiveTerm() async {
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
    // Try 12-hour formats with AM/PM first, then fall back to 24-hour formats
    final fmts = ['h:mm a', 'hh:mm a', 'H:mm', 'HH:mm'];
    for (final f in fmts) {
      try {
        final dt = DateFormat(f). parse(timeStr);
        return dt.hour * 60 + dt.minute;
      } catch (_) {}
    }
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