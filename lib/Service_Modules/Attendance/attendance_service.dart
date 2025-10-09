import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ============================ DATA MODELS ============================

/// View modes
enum ViewMode { daily, weekly, monthly }

/// Attendance status (EXPANDED for new logic)
enum SessStatus { scheduled, present, late, absent, excused }

/// A scheduled class meeting. This model is adapted to match Firestore data.
class Session {
  final String id;
  final String subject;
  final String section;
  final String room;
  final TimeOfDay start;
  final TimeOfDay end;
  final String? instructorId;
  final String instructorName;
  final String? kind; // e.g., "Lab", "ComLab"

  const Session({
    required this.id,
    required this.subject,
    required this.section,
    required this.room,
    required this.start,
    required this.end,
    this.instructorId,
    required this.instructorName,
    this.kind,
  });
}

// Models for "View Details" functionality, adapted from the schedule module
class SectionStudent {
  final String name;
  final String? photoURL;
  SectionStudent({required this.name, this.photoURL});
}

class InstructorDetails {
  final String name;
  final String? departmentName;
  final String? photoURL;
  InstructorDetails({required this.name, this.departmentName, this.photoURL});
}

// UI models (from original attendance module)
class SubjectDayGroup {
  final String subjectDisplay;
  final List<Session> sessions;
  const SubjectDayGroup({required this.subjectDisplay, required this.sessions});
}

class SubjectWeekItem {
  final String subjectDisplay;
  final List<bool> week;
  final int attended;
  final int total;
  final List<SessStatus?> statuses;
  const SubjectWeekItem({
    required this.subjectDisplay,
    required this.week,
    required this.attended,
    required this.total,
    required this.statuses,
  });
}

class SubjectTotals {
  final String subjectDisplay;
  final int attended;
  final int total;
  const SubjectTotals({required this.subjectDisplay, required this.attended, required this.total});
}

class Counts {
  final int present, lates, absents;
  const Counts(this.present, this.lates, this.absents);
}

String displayName(Session s) => s.kind == null ? s.subject : "${s.subject} (${s.kind})";

// ============================ SERVICE INTERFACE ============================

abstract class AttendanceService {
  Future<Map<DateTime, List<Session>>> getSessionsForRange({
    required String userId,
    required String role,
    required DateTime start,
    required DateTime end,
  });

  Future<SessStatus> getStatusFor({
    required String userId,
    required DateTime date,
    required Session session,
  });

  // Methods for details panel
  Future<List<SectionStudent>> fetchStudentsForSection({required String sectionName});
  Future<InstructorDetails?> fetchInstructorDetails({required String instructorId});
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
    final activeIds = await _findActiveAcademicIds();
    if (activeIds == null) {
      throw Exception('No active academic term found. Please contact an administrator.');
    }

    final user = await _fetchUserDetails(role: role, uid: userId);
    if (user == null) {
      throw Exception('Could not find user details.');
    }

    final pathIds = {
      'departmentId': _idOf(user['department'] ?? user['departmentId']),
      'courseId': _idOf(user['course'] ?? user['courseId']),
      'yearLevelId': _idOf(user['yearLevel'] ?? user['yearLevelId']),
      'sectionId': _idOf(user['section'] ?? user['sectionId']),
    };

    if (pathIds.containsValue(null)) {
      throw Exception('Your account is missing required academic information (department, course, etc.).');
    }

    final sectionPath = 'academic_years/${activeIds['academicYearId']}'
        '/semesters/${activeIds['semesterId']}'
        '/departments/${pathIds['departmentId']}'
        '/courses/${pathIds['courseId']}'
        '/year_levels/${pathIds['yearLevelId']}'
        '/sections/${pathIds['sectionId']}';

    final sectionName = _strOrNull(user['sectionName']);
    final daysToFetch = _getWeekdayKeysInRange(start, end);

    final query = _db.doc(sectionPath).collection('schedules').where('days', arrayContainsAny: daysToFetch);
    final snap = await query.get();

    final sessionsByWeekday = <String, List<Session>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final days = (data['days'] as List<dynamic>?)?.map((d) => d.toString()).toList() ?? [];
      for (final dayKey in days) {
        sessionsByWeekday.putIfAbsent(dayKey, () => []).add(_mapDocToSession(doc, sectionName: sectionName));
      }
    }

    final results = <DateTime, List<Session>>{};
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final dayKey = DateFormat('EEEE').format(d).toLowerCase();
      final sessions = sessionsByWeekday[dayKey] ?? [];
      sessions.sort((a, b) => (a.start.hour * 60 + a.start.minute).compareTo(b.start.hour * 60 + b.start.minute));
      results[d] = sessions;
    }
    return results;
  }

  @override
  Future<SessStatus> getStatusFor({
    required String userId,
    required DateTime date,
    required Session session,
  }) async {
    // As requested, this is a placeholder.
    // In a real implementation, you would query a 'daily_attendance' collection.
    return SessStatus.scheduled;
  }

  // --- Detail Panel Fetching ---

  @override
  Future<List<SectionStudent>> fetchStudentsForSection({required String sectionName}) async {
    final query = _db.collectionGroup('accounts').where('role', isEqualTo: 'Student').where('sectionName', isEqualTo: sectionName);
    final snap = await query.get();
    final students = snap.docs.map((d) => SectionStudent(
      name: _combineName(d.data(), fallback: 'Unknown Student'),
      photoURL: _strOrNull(d.data()['photoURL']),
    )).toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
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

  // --- Internal Helpers (from home_service.dart) ---

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

  Session _mapDocToSession(QueryDocumentSnapshot<Map<String, dynamic>> d, {String? sectionName}) {
    final data = d.data();
    final startStr = (data['startTime'] ?? data['timeStart'] ?? '').toString();
    final endStr = (data['endTime'] ?? data['timeEnd'] ?? '').toString();

    return Session(
      id: d.id,
      subject: (data['subjectName'] ?? data['subjectCode'] ?? 'No Subject').toString(),
      section: sectionName ?? 'No Section',
      room: _strOrNull(data['roomName'] ?? data['room']) ?? 'N/A',
      start: _parseTime(startStr),
      end: _parseTime(endStr),
      instructorId: _strOrNull(data['instructorId']),
      instructorName: (data['instructorName'] ?? 'N/A').toString(),
      kind: _strOrNull(data['kind']),
    );
  }

  List<String> _getWeekdayKeysInRange(DateTime start, DateTime end) {
    final keys = <String>{};
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      keys.add(DateFormat('EEEE').format(d).toLowerCase());
    }
    return keys.toList();
  }

  TimeOfDay _parseTime(String timeStr) {
    if (timeStr.isEmpty) return const TimeOfDay(hour: 0, minute: 0);
    final fmts = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a'];
    for (final f in fmts) {
      try {
        final dt = DateFormat(f).parse(timeStr);
        return TimeOfDay.fromDateTime(dt);
      } catch (_) {}
    }
    return const TimeOfDay(hour: 0, minute: 0);
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
}