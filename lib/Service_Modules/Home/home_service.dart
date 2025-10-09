import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart'; // **THE FIX IS HERE**
import 'home_UI.dart'; // for ScheduleItem and other models
import 'dart:async';

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

  /// **NEW LOGIC**: Finds the currently active academic year and semester globally.
  Future<Map<String, String>?> _findActiveAcademicIds() async {
    final yearQuery = _db.collection('academic_years').where('status', isEqualTo: 'Active').limit(1);
    final yearSnap = await yearQuery.get();

    if (yearSnap.docs.isEmpty) {
      debugPrint("[HomeService] VALIDATION FAILED: No 'Active' academic year found.");
      return null;
    }
    final activeYearId = yearSnap.docs.first.id;

    final semesterQuery = _db.collection('academic_years').doc(activeYearId).collection('semesters').where('status', isEqualTo: 'Active').limit(1);
    final semesterSnap = await semesterQuery.get();

    if (semesterSnap.docs.isEmpty) {
      debugPrint("[HomeService] VALIDATION FAILED: No 'Active' semester found in year '$activeYearId'.");
      return null;
    }
    final activeSemesterId = semesterSnap.docs.first.id;

    debugPrint("[HomeService] Found active term: Year '$activeYearId', Semester '$activeSemesterId'.");
    return {'academicYearId': activeYearId, 'semesterId': activeSemesterId};
  }

  // ============================ SCHEDULES ============================

  Stream<List<ScheduleItem>> streamSchedulesForStudent({
    required String role,
    required String uid,
  }) async* {
    debugPrint("[HomeService] Starting STUDENT schedule stream.");
    final activeIds = await _findActiveAcademicIds();
    if (activeIds == null) {
      yield [];
      return;
    }

    final user = await fetchUserDetails(role: role, uid: uid);
    if (user == null) {
      yield [];
      return;
    }
    final departmentId = _idOf(user['department'] ?? user['departmentId']);
    final courseId = _idOf(user['course'] ?? user['courseId']);
    final yearLevelId = _idOf(user['yearLevel'] ?? user['yearLevelId']);
    final sectionId = _idOf(user['section'] ?? user['sectionId']);

    if ([departmentId, courseId, yearLevelId, sectionId].any((v) => v == null || v.isEmpty)) {
      debugPrint("[HomeService] Student is missing path IDs. Emitting empty list.");
      yield [];
      return;
    }

    final sectionPath =
        'academic_years/${activeIds['academicYearId']}'
        '/semesters/${activeIds['semesterId']}'
        '/departments/$departmentId'
        '/courses/$courseId'
        '/year_levels/$yearLevelId'
        '/sections/$sectionId';

    final sectionName = _strOrNull(user['sectionName']);
    final todayKey = _todayDay();

    final query = _db.doc(sectionPath).collection('schedules').where('days', arrayContains: todayKey);

    await for (final snap in query.snapshots()) {
      debugPrint("[HomeService] Student stream received ${snap.docs.length} documents.");
      final items = _mapSnapToScheduleItems(snap.docs, sectionName: sectionName);
      yield items;
    }
  }

  Stream<List<ScheduleItem>> streamSchedulesForTeacher({
    required String teacherUid,
  }) async* {
    debugPrint("[HomeService] Starting STAFF schedule stream.");
    final activeIds = await _findActiveAcademicIds();
    if (activeIds == null) {
      yield [];
      return;
    }

    final todayKey = _todayDay();
    final query = _db.collectionGroup('schedules')
        .where('instructorId', isEqualTo: teacherUid)
        .where('days', arrayContains: todayKey);

    await for (final snap in query.snapshots()) {
      final activeSchedules = snap.docs.where((doc) {
        final path = doc.reference.path;
        return path.contains(activeIds['academicYearId']!) && path.contains(activeIds['semesterId']!);
      }).toList();

      debugPrint("[HomeService] Staff stream received ${activeSchedules.length} active documents.");

      final itemsWithSections = await Future.wait(activeSchedules.map((doc) async {
        String? sectionName;
        final sectionDocRef = doc.reference.parent.parent;
        if (sectionDocRef != null) {
          final sectionDoc = await sectionDocRef.get();
          sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
        }
        return _mapSingleDocToScheduleItem(doc, sectionName: sectionName);
      }));

      itemsWithSections.sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
      yield itemsWithSections;
    }
  }

  // ===================== Chip-tap Details Fetching =====================

  Future<InstructorDetails?> fetchInstructorDetails(String instructorId) async {
    // This logic remains the same.
    try {
      final doc = await _db.collection('users/teacher/accounts').doc(instructorId).get();
      if (!doc.exists) return null;
      return InstructorDetails(
        name: _combineName(doc.data()!, fallback: 'Unknown Instructor'),
        departmentName: _strOrNull(doc.data()!['departmentName']),
        photoURL: _strOrNull(doc.data()!['photoURL']),
        firstName: _strOrNull(doc.data()!['firstName']) ?? '',
        lastName: _strOrNull(doc.data()!['lastName']) ?? '',
      );
    } catch (e) {
      debugPrint("[HomeService] Error fetching instructor details: $e");
      return null;
    }
  }

  Future<List<SectionStudent>> fetchStudentsForSection(String sectionName) async {
    // This logic remains the same.
    try {
      final query = _db.collectionGroup('accounts').where('role', isEqualTo: 'Student').where('sectionName', isEqualTo: sectionName);
      final snap = await query.get();
      final students = snap.docs.map((d) => SectionStudent(
        name: _combineName(d.data(), fallback: 'Unknown Student'),
        firstName: _strOrNull(d.data()['firstName']),
        lastName: _strOrNull(d.data()['lastName']),
        photoURL: _strOrNull(d.data()['photoURL']),
      )).toList();
      students.sort((a, b) => (a.lastName ?? '').compareTo(b.lastName ?? ''));
      return students;
    } catch (e) {
      debugPrint("[HomeService] Error fetching students for section: $e");
      return [];
    }
  }

  /// **FIX**: This method now accepts a date to be consistent.
  Future<List<ScheduleItem>> fetchSchedulesForRoom({required String roomName, required DateTime forDate}) async {
    try {
      final dayKey = DateFormat('EEEE').format(forDate).toLowerCase();
      final query = _db.collectionGroup('schedules').where('roomName', isEqualTo: roomName).where('days', arrayContains: dayKey);
      final snap = await query.get();

      final itemsWithSections = await Future.wait(snap.docs.map((doc) async {
        String? sectionName;
        final sectionDocRef = doc.reference.parent.parent;
        if (sectionDocRef != null) {
          final sectionDoc = await sectionDocRef.get();
          sectionName = _strOrNull(sectionDoc.data()?['sectionName']);
        }
        return _mapSingleDocToScheduleItem(doc, sectionName: sectionName);
      }));

      itemsWithSections.sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
      return itemsWithSections;

    } catch (e) {
      debugPrint("[HomeService] Error fetching schedules for room: $e");
      return [];
    }
  }

  // ============================ HELPERS ============================

  /// SHARED mapping logic.
  List<ScheduleItem> _mapSnapToScheduleItems(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {String? sectionName}) {
    final items = docs.map((d) => _mapSingleDocToScheduleItem(d, sectionName: sectionName)).toList();
    items.sort((a, b) => _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
    return items;
  }

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

  String? _idOf(dynamic v) {
    if (v == null) return null;
    if (v is DocumentReference) return v.id;
    if (v is String && v.isNotEmpty) return v.contains('/') ? v.split('/').last : v;
    return null;
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