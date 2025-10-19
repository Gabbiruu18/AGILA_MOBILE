import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// ============================ DATA MODELS (UPDATED) ============================

// NEW: Copied from attendance module
enum AttendanceStatus { scheduled, present, late, absent, excused }

class Session {
  final String id;
  final String subject;
  final String section;
  final String room;
  // NEW: Copied from attendance module
  final String roomType;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final int colorHex;
  final String instructorId;
  final String? instructorName;
  // NEW: Copied from attendance module
  final AttendanceStatus status;

  const Session({
    required this.id,
    required this.subject,
    required this.section,
    required this.room,
    required this.roomType, // NEW
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.colorHex,
    required this.instructorId,
    this.instructorName,
    this.status = AttendanceStatus.scheduled, // NEW
  });

  // NEW: Copied from attendance module
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
    );
  }
}

class SectionStudent {
  // NEW: Added UID for combining lists
  final String uid;
  final String name;
  final String? photoURL;
  SectionStudent({required this.uid, required this.name, this.photoURL});
}

// NEW: Copied from attendance module
class InstructorDetails {
  final String name;
  final String? departmentName;
  final String? photoURL;
  InstructorDetails({required this.name, this.departmentName, this.photoURL});
}

class RoomSchedule {
  final String subjectName;
  final String professor;
  final String sectionName;
  final String time;
  RoomSchedule({required this.subjectName, required this.professor, required this.sectionName, required this.time});
}

// NEW: Copied from attendance module
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

// ============================ SERVICE INTERFACE (UPDATED) ============================

abstract class ScheduleService {
  // UPDATED: Now returns ActiveTerm as well
  Future<(Map<DateTime, List<Session>>, ActiveTerm?)> getSessionsForRange({
    required String userId,
    required String role,
    required DateTime start,
    required DateTime end,
  });

  // UPDATED: Now requires scheduleId for fetching irregular students
  Future<List<SectionStudent>> fetchStudentsForSection({
    required String sectionName,
    required String scheduleId,
  });

  Future<List<RoomSchedule>> fetchSchedulesForRoom({required String roomName, required DateTime forDate});

  // NEW: Copied from attendance module
  Future<InstructorDetails?> fetchInstructorDetails({required String instructorId});
}

// ============================ FIRESTORE IMPLEMENTATION (UPDATED) ============================

class FirestoreScheduleService implements ScheduleService {
  final FirebaseFirestore _db;
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

    // TODO: Add logic to fetch real attendance records here later.
    // For now, all sessions will have the default 'scheduled' status.

    final results = <DateTime, List<Session>>{};
    final sessionsByWeekday = <int, List<Session>>{};
    for (final session in allSessions) {
      sessionsByWeekday.putIfAbsent(session.weekday, () => []).add(session);
    }

    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final sessionsForDay = sessionsByWeekday[d.weekday] ?? [];
      sessionsForDay.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      results[d] = sessionsForDay;
    }
    return (results, activeTerm);
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
  Future<List<SectionStudent>> fetchStudentsForSection({required String sectionName, required String scheduleId}) async {
    // This logic is copied and adapted from the attendance module.
    try {
      final regularQuery = _db.collectionGroup('accounts').where('role', isEqualTo: 'Student').where('academicStatus', isEqualTo: 'regular').where('sectionName', isEqualTo: sectionName);
      final regularSnap = await regularQuery.get();
      final regularStudents = regularSnap.docs.map((d) => SectionStudent(uid: d.id, name: _combineName(d.data(), fallback: 'Unknown'), photoURL: _strOrNull(d.data()['photoURL']))).toList();

      final scheduleQuery = _db.collectionGroup('schedules').where(FieldPath.documentId, isEqualTo: scheduleId).limit(1);
      final scheduleSnap = await scheduleQuery.get();
      if(scheduleSnap.docs.isEmpty) {
        regularStudents.sort((a, b) => a.name.compareTo(b.name));
        return regularStudents;
      }
      final scheduleRef = scheduleSnap.docs.first.reference;

      final irregularQuery = scheduleRef.collection('enrolled_students');
      final irregularSnap = await irregularQuery.get();
      final irregularStudentUIDs = irregularSnap.docs.map((d) => d.id).toList();

      var irregularStudents = <SectionStudent>[];
      if (irregularStudentUIDs.isNotEmpty) {
        final studentDetailsQuery = _db.collection('users/Student/accounts').where(FieldPath.documentId, whereIn: irregularStudentUIDs);
        final studentDetailsSnap = await studentDetailsQuery.get();
        irregularStudents = studentDetailsSnap.docs.map((d) => SectionStudent(uid: d.id, name: _combineName(d.data(), fallback: 'Unknown'), photoURL: _strOrNull(d.data()['photoURL']))).toList();
      }

      final allStudents = <String, SectionStudent>{};
      for (final s in regularStudents) { allStudents[s.uid] = s; }
      for (final s in irregularStudents) { allStudents[s.uid] = s; }

      final finalRoster = allStudents.values.toList();
      finalRoster.sort((a, b) => a.name.compareTo(b.name));
      return finalRoster;
    } catch (e) {
      debugPrint("[ScheduleService] Error fetching students for section '$sectionName': $e");
      return [];
    }
  }

  @override
  Future<InstructorDetails?> fetchInstructorDetails({required String instructorId}) async {
    // This logic is copied from the attendance module.
    if (instructorId.trim().isEmpty) return null;

    final docRef = _db.collection('users/teacher/accounts').doc(instructorId);
    final doc = await docRef.get();

    if (!doc.exists) return null;

    return InstructorDetails(
      name: _combineName(doc.data()!, fallback: 'Unknown Instructor'),
      departmentName: _strOrNull(doc.data()!['departmentName']),
      photoURL: _strOrNull(doc.data()!['photoURL']),
    );
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
      debugPrint("[ScheduleService] Error fetching schedules for room '$roomName': $e");
      return [];
    }
  }

  // ============================ HELPERS (UPDATED) ============================

  Future<ActiveTerm?> _findActiveTerm() async {
    final yearSnap = await _db.collection('academic_years').where('status', isEqualTo: 'Active').limit(1).get();
    if (yearSnap.docs.isEmpty) return null;
    final yearDoc = yearSnap.docs.first;

    final semSnap = await yearDoc.reference.collection('semesters').where('status', isEqualTo: 'Active').limit(1).get();
    if (semSnap.docs.isEmpty) return null;
    final semDoc = semSnap.docs.first;
    final semData = semDoc.data();

    final startDateString = semData['startDate'] as String?;
    final endDateString = semData['endDate'] as String?;

    final startDate = (startDateString != null && startDateString.isNotEmpty) ? DateTime.parse(startDateString) : DateTime.now();
    final endDate = (endDateString != null && endDateString.isNotEmpty) ? DateTime.parse(endDateString) : DateTime.now().add(const Duration(days: 120));

    return ActiveTerm(academicYearId: yearDoc.id, semesterId: semDoc.id, startDate: startDate, endDate: endDate);
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

    return weekdays.map((weekday) {
      return Session(
        id: d.id,
        subject: (data['subjectName'] ?? data['subjectCode'] ?? 'No Subject').toString(),
        section: sectionName ?? 'No Section',
        room: _strOrNull(data['roomName'] ?? data['room']) ?? 'N/A',
        roomType: (data['roomType'] as String?)?.toUpperCase() ?? 'LECTURE', // NEW
        weekday: weekday,
        startMinutes: _parseTimeToMinutes(startStr),
        endMinutes: _parseTimeToMinutes(endStr),
        colorHex: _parseColorHex(data['color']),
        instructorId: (data['instructorId'] ?? '').toString(),
        instructorName: (data['instructorName'] ?? '').toString(),
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
    final combined = [firstName, lastName].where((n) => n != null && n.isNotEmpty).join(' ');
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