import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// ============================ DATA MODELS ============================

class Session {
  final String id;
  final String subject;
  final String section;
  final String room;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final int colorHex;
  final String instructorId;
  final String? instructorName;

  const Session({
    required this.id,
    required this.subject,
    required this.section,
    required this.room,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.colorHex,
    required this.instructorId,
    this.instructorName,
  });
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

// ============================ SERVICE INTERFACE ============================

abstract class AttendanceService {
  Future<Map<DateTime, List<Session>>> getSessionsForRange({
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
}

// ============================ FIRESTORE IMPLEMENTATION ============================

class FirestoreAttendanceService implements AttendanceService {
  final FirebaseFirestore _db;
  FirestoreAttendanceService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  // --- Main Data Fetching ---

  @override
  Future<Map<DateTime, List<Session>>> getSessionsForRange({
    required String userId,
    required String role,
    required DateTime start,
    required DateTime end,
  }) async {
    final academicIds = await _findActiveAcademicIds();
    if (academicIds == null) {
      throw Exception('No active academic term is set. Please contact an administrator.');
    }

    final isTeacher = role == 'teacher' || role == 'program_head';

    List<Session> allSessions;
    if (isTeacher) {
      allSessions = await _fetchTeacherSchedules(uid: userId, academicIds: academicIds);
    } else {
      allSessions = await _fetchStudentSchedules(uid: userId, role: role, academicIds: academicIds);
    }

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
    return results;
  }

  // --- Teacher Schedule Logic ---
  Future<List<Session>> _fetchTeacherSchedules({required String uid, required Map<String, String> academicIds}) async {
    final query = _db.collectionGroup('schedules').where('instructorId', isEqualTo: uid);
    final snap = await query.get();
    final activeSchedules = snap.docs.where((doc) {
      final path = doc.reference.path;
      return path.contains(academicIds['academicYearId']!) && path.contains(academicIds['semesterId']!);
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

  // --- Student Schedule Logic ---
  Future<List<Session>> _fetchStudentSchedules({required String uid, required String role, required Map<String, String> academicIds}) async {
    final userDetails = await _fetchUserDetails(role: role, uid: uid);
    if (userDetails == null) throw Exception('Could not find your user details.');

    final academicStatus = _strOrNull(userDetails['academicStatus']) ?? 'regular';

    if (academicStatus == 'regular') {
      return _fetchRegularStudentSchedule(userDetails: userDetails, academicIds: academicIds);
    } else {
      return _fetchIrregularStudentSchedule(uid: uid, academicIds: academicIds);
    }
  }

  Future<List<Session>> _fetchRegularStudentSchedule({required Map<String, dynamic> userDetails, required Map<String, String> academicIds}) async {
    final pathIds = {
      'departmentId': _idOf(userDetails['department']),
      'courseId': _idOf(userDetails['course']),
      'yearLevelId': _idOf(userDetails['yearLevel']),
      'sectionId': _idOf(userDetails['section']),
    };

    if (pathIds.containsValue(null)) throw Exception('Your account is missing required academic information.');

    final sectionPath = 'academic_years/${academicIds['academicYearId']}/semesters/${academicIds['semesterId']}/departments/${pathIds['departmentId']}/courses/${pathIds['courseId']}/year_levels/${pathIds['yearLevelId']}/sections/${pathIds['sectionId']}';
    final query = _db.doc(sectionPath).collection('schedules');
    final snap = await query.get();

    final sectionName = _strOrNull(userDetails['sectionName']);
    final itemsWithData = snap.docs.map((doc) => _mapDocToSessions(doc, sectionName: sectionName)).toList();
    return itemsWithData.expand((sessions) => sessions).toList();
  }

  Future<List<Session>> _fetchIrregularStudentSchedule({required String uid, required Map<String, String> academicIds}) async {
    final query = _db.collectionGroup('enrolled_students').where(FieldPath.documentId, isEqualTo: uid);
    final enrolledSnap = await query.get();
    if (enrolledSnap.docs.isEmpty) return [];

    final scheduleRefs = enrolledSnap.docs.map((doc) => doc.reference.parent.parent).where((ref) => ref != null).toList();

    final activeSchedules = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for(final ref in scheduleRefs) {
      if(ref!.path.contains(academicIds['academicYearId']!) && ref.path.contains(academicIds['semesterId']!)) {
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

  // --- Detail Panel Fetching ---

  @override
  Future<List<SectionStudent>> fetchStudentsForSection({required String sectionName, required String scheduleId}) async {
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
      debugPrint("[AttendanceService] Error fetching students for section '$sectionName': $e");
      return [];
    }
  }

  @override
  Future<InstructorDetails?> fetchInstructorDetails({required String instructorId}) async {
    final doc = await _db.collection('users/teacher/accounts').doc(instructorId).get();
    if (!doc.exists) return null;
    return InstructorDetails(
      name: _combineName(doc.data()!, fallback: 'Unknown Instructor'),
      departmentName: _strOrNull(doc.data()!['departmentName']),
      photoURL: _strOrNull(doc.data()!['photoURL']),
    );
  }

  // --- Internal Helpers ---

  Future<Map<String, String>?> _findActiveAcademicIds() async {
    final yearSnap = await _db.collection('academic_years').where('status', isEqualTo: 'Active').limit(1).get();
    if (yearSnap.docs.isEmpty) return null;
    final yearId = yearSnap.docs.first.id;

    final semSnap = await _db.collection('academic_years').doc(yearId).collection('semesters').where('status', isEqualTo: 'Active').limit(1).get();
    if (semSnap.docs.isEmpty) return null;
    final semId = semSnap.docs.first.id;

    return {'academicYearId': yearId, 'semesterId': semId};
  }

  Future<Map<String, dynamic>?> _fetchUserDetails({required String role, required String uid}) async {
    final snap = await _db.collection('users').doc(role).collection('accounts').doc(uid).get();
    return snap.data();
  }

  List<Session> _mapDocToSessions(QueryDocumentSnapshot<Map<String, dynamic>> d, {String? sectionName}) {
    final data = d.data();
    final days = (data['days'] as List<dynamic>?)?.map((day) => _dayNameToWeekday(day.toString())).where((d) => d != -1).toList() ?? [];
    final startStr = (data['startTime'] ?? data['timeStart'] ?? '').toString();
    final endStr = (data['endTime'] ?? data['timeEnd'] ?? '').toString();

    return days.map((weekday) {
      return Session(
        id: d.id,
        subject: (data['subjectName'] ?? data['subjectCode'] ?? 'No Subject').toString(),
        section: sectionName ?? 'No Section',
        room: _strOrNull(data['roomName'] ?? data['room']) ?? 'N/A',
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

  String? _strOrNull(dynamic v) => (v ?? '').toString().trim().isEmpty ? null : v.toString().trim();

  String _combineName(Map<String, dynamic> data, {required String fallback}) {
    final f = _strOrNull(data['firstName']);
    final l = _strOrNull(data['lastName']);
    final combined = [f, l].where((n) => n != null).join(' ');
    return combined.isNotEmpty ? combined : (_strOrNull(data['name']) ?? fallback);
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