import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'home_UI.dart'; // for ScheduleItem

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

  /// Extract IDs from the user doc. Accepts either DocumentReference or String.
  /// Returns a map including a resolved `sectionPath` built from IDs.
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
    final sectionId      = _idOf(user['section']      ?? user['sectionId']); // <— use `section` field

    // Require all IDs to build the path deterministically
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
      // Optional display fields (if you store them)
      'courseName': _strOrNull(user['courseName']) ?? '',
      'departmentName': _strOrNull(user['departmentName']) ?? '',
      'sectionName': _strOrNull(user['sectionName']) ?? '',
    };
  }

  String? _idOf(dynamic v) {
    if (v == null) return null;
    if (v is DocumentReference) return v.id;
    if (v is String && v.isNotEmpty) {
      return v.contains('/') ? v.split('/').last : v;
    }
    return null;
  }

  // ============================ SCHEDULES ============================

  /// Main entry: always uses IDs (via `section` doc id) to go straight to the section.
  Future<List<ScheduleItem>> fetchTodaySchedulesForUser({
    required String role,
    required String uid,
  }) async {

    final ids = await getAcademicIdsFromUser(role: role, uid: uid);
    if (ids == null) return <ScheduleItem>[];

    final sectionPath = ids['sectionPath']!;
    return fetchTodaySchedulesBySectionPath(sectionPath: sectionPath);
  }

  /// Read schedules in the section and filter to "today" via `days` array (e.g., "Monday").
  Future<List<ScheduleItem>> fetchTodaySchedulesBySectionPath({
    required String sectionPath, // academic_years/.../sections/{sectionId}
  }) async {
    final todayKey = _todayDay();

    final sectionRef = _db.doc(sectionPath);
    final snap = await sectionRef
        .collection('schedules')
        .where('days', arrayContains: todayKey)
        .get();

    final items = <ScheduleItem>[];
    for (final d in snap.docs) {
      final data = d.data();

      // Expected fields (customize as needed for your schema)
      final start = (data['startTime'] ?? data['timeStart'] ?? '').toString();
      final end   = (data['endTime']   ?? data['timeEnd']   ?? '').toString();

      items.add(
        ScheduleItem(
          subjectName: (data['subjectName'] ?? data['subjectCode'] ?? '').toString(),
          professor: (data['instructorName'] ?? '').toString(),
          startTime: start,
          endTime: end,
          courseName: _strOrNull(data['courseName']),
          sectionName: _strOrNull(data['sectionName']),
          room: _strOrNull(data['roomName'] ?? data['room']),
        ),
      );
    }

    // Sort by start time (supports "HH:mm" or "h:mm a")
    items.sort((a, b) =>
        _parseTimeToMinutes(a.startTime).compareTo(_parseTimeToMinutes(b.startTime)));
    return items;
  }

  String _todayDay() {
    // 1=Mon..7=Sun
    const keys = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
    final weekday = DateTime.now().weekday;
    return keys[weekday - 1];
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
