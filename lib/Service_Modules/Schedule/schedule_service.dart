import 'dart:async';
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
  final String name;
  final String? photoURL;
  SectionStudent({required this.name, this.photoURL});
}

class RoomSchedule {
  final String subjectName;
  final String professor;
  final String sectionName;
  final String time;
  RoomSchedule({required this.subjectName, required this.professor, required this.sectionName, required this.time});
}

// ============================ SERVICE ============================

abstract class ScheduleService {
  Future<Map<int, List<Session>>> fetchWeek({required String uid, required String role});
  Future<List<SectionStudent>> fetchStudentsForSection({required String sectionName});
  Future<List<RoomSchedule>> fetchSchedulesForRoom({required String roomName, required DateTime forDate});
}

class FirestoreScheduleService implements ScheduleService {
  final FirebaseFirestore _db;
  FirestoreScheduleService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  // ==================== NEW: Independent Academic Logic ====================

  /// **NEW LOGIC**: Finds the currently active academic year and semester,
  /// without needing to check the user's document first.
  Future<Map<String, String>?> _findActiveAcademicIds() async {
    // 1. Find the active academic year.
    final yearQuery = _db.collection('academic_years').where('status', isEqualTo: 'Active').limit(1);
    final yearSnap = await yearQuery.get();

    if (yearSnap.docs.isEmpty) {
      debugPrint("[ScheduleService] VALIDATION FAILED: No 'Active' academic year found in the database.");
      return null;
    }
    final activeYearId = yearSnap.docs.first.id;

    // 2. Find the active semester within that year.
    final semesterQuery = _db.collection('academic_years').doc(activeYearId).collection('semesters').where('status', isEqualTo: 'Active').limit(1);
    final semesterSnap = await semesterQuery.get();

    if (semesterSnap.docs.isEmpty) {
      debugPrint("[ScheduleService] VALIDATION FAILED: No 'Active' semester found within the active year '$activeYearId'.");
      return null;
    }
    final activeSemesterId = semesterSnap.docs.first.id;

    debugPrint("[ScheduleService] Found active term: Year '$activeYearId', Semester '$activeSemesterId'.");
    return {'academicYearId': activeYearId, 'semesterId': activeSemesterId};
  }

  // ==================== Main Service Methods ====================

  @override
  Future<Map<int, List<Session>>> fetchWeek({required String uid, required String role}) async {
    // **THE FIX**: The service now finds the globally active IDs.
    final academicIds = await _findActiveAcademicIds();
    if (academicIds == null) {
      debugPrint("[ScheduleService] Cannot fetch week. No active academic term found.");
      // Provide a more specific error message to the user.
      throw Exception('No active academic term is set. Please contact an administrator.');
    }

    final bool isTeacher = role == 'teacher' || role == 'program_head';

    if (isTeacher) {
      final query = _db.collectionGroup('schedules').where('instructorId', isEqualTo: uid);
      try {
        final snap = await query.get();
        // Further filter to ensure schedules are within the active academic period
        final activeSchedules = snap.docs.where((doc) {
          final path = doc.reference.path;
          return path.contains(academicIds['academicYearId']!) && path.contains(academicIds['semesterId']!);
        }).toList();

        debugPrint("[ScheduleService] Found ${activeSchedules.length} schedules for teacher '$uid' in the active semester.");

        final itemsWithData = await Future.wait(activeSchedules.map((doc) async {
          String? sectionName;
          final sectionDocRef = doc.reference.parent.parent;
          if (sectionDocRef != null) {
            final sectionDoc = await sectionDocRef.get();
            sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
          }
          return _mapDocToSessions(doc, sectionName: sectionName);
        }));

        return _groupSessionsByWeekday(itemsWithData);
      } catch (e, s) {
        debugPrint("[ScheduleService] CRITICAL ERROR in fetchWeek: $e\n$s");
        throw Exception('Failed to load schedules.');
      }
    } else {
      debugPrint("[ScheduleService] Student schedule logic in ScheduleService is not implemented.");
      return {};
    }
  }

  @override
  Future<List<SectionStudent>> fetchStudentsForSection({required String sectionName}) async {
    // This logic remains the same.
    try {
      final query = _db.collectionGroup('accounts').where('role', isEqualTo: 'Student').where('sectionName', isEqualTo: sectionName);
      final snap = await query.get();
      final students = snap.docs.map((d) {
        return SectionStudent(
          name: _combineName(d.data(), fallback: 'Unknown Student'),
          photoURL: _strOrNull(d.data()['photoURL']),
        );
      }).toList();
      students.sort((a, b) => a.name.compareTo(b.name));
      return students;
    } catch (e) {
      debugPrint("[ScheduleService] Error fetching students for section '$sectionName': $e");
      return [];
    }
  }

  @override
  Future<List<RoomSchedule>> fetchSchedulesForRoom({required String roomName, required DateTime forDate}) async {
    // This logic remains the same.
    try {
      final dayKey = DateFormat('EEEE').format(forDate).toLowerCase();
      debugPrint("[ScheduleService] Fetching schedules for room '$roomName' on '$dayKey'.");

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

  // ============================ HELPERS ============================

  Map<int, List<Session>> _groupSessionsByWeekday(List<List<Session>> itemsWithData) {
    final groupedByWeekday = <int, List<Session>>{};
    final allSessions = itemsWithData.expand((sessions) => sessions);
    for (final session in allSessions) {
      (groupedByWeekday[session.weekday] ??= []).add(session);
    }
    groupedByWeekday.values.forEach((list) => list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes)));
    return groupedByWeekday;
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
        instructorName: (data['instructorName'] ?? '').toString(),
      );
    }).toList();
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