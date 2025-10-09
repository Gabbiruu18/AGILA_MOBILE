import 'dart:async';
import 'package:flutter/material.dart';
import 'home_service.dart';
import 'home_UI.dart';

class HomeController extends ChangeNotifier {
  final HomeService _service;
  HomeController({HomeService? service}) : _service = service ?? HomeService();
  bool _isDisposed = false;

  // ---------- Identity ----------
  late String role;
  late String uid;
  late String name = '';

  // ---------- Role Checker ----------
  bool get isTeacherOrHead =>
      role == 'teacher' || role == 'program_head';

  // ---------- Display chips / labels ----------
  String? courseRaw;
  String? departmentRaw;
  String? course;
  String? section;
  String? department;

  // ---------- Notes & unread ----------
  String noteText = 'Tap to write notes';
  int unreadCount = 0;
  StreamSubscription<int>? _unreadSub;

  // ---------- Loading & errors ----------
  bool isLoading = true;
  bool isLoadingSchedules = false;
  String? schedulesError;

  // ---------- Today schedules exposed to UI ----------
  List<ScheduleItem> todaySchedules = const [];
  StreamSubscription<List<ScheduleItem>>? _schedulesSub;

  // ---------- Chip Details Data ----------
  InstructorDetails? _instructorDetails;
  List<SectionStudent>? _sectionRoster;
  List<ScheduleItem>? _roomSchedule;

  Future<void> init({
    required String role,
    required String uid,
  }) async {
    this.role = role;
    this.uid = uid;

    isLoading = true;
    notifyListeners();

    try {
      final user = await _service.fetchUserDetails(role: role, uid: uid) ?? {};
      this.name = combineName(user, fallback: 'User');

      courseRaw     = user['courseName']?.toString();
      departmentRaw = user['departmentName']?.toString();
      section       = user['sectionName']?.toString();

      final docRole = user['role']?.toString();
      if (docRole != null && docRole != role) {
        debugPrint("WARNING: Role mismatch! Passed role: '$role', Firestore role: '$docRole'");
      }

      course     = _toAcronym(courseRaw ?? '', maxLetters: 4);
      department = _toAcronym(departmentRaw ?? '');
      noteText = await _service.getOrCreateNote(role: role, uid: uid);

      _unreadSub?.cancel();
      _unreadSub = _service.streamUnreadCount(role: role, uid: uid).listen((n) {
        unreadCount = n;
        if (hasListeners) notifyListeners();
      });

      initTodaySchedulesRealtime();
    } catch (e, s) {
      debugPrint("[HomeController] CRITICAL ERROR during init: $e\n$s");
      this.name = 'Error Loading Name';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void initTodaySchedulesRealtime() {
    if (isLoadingSchedules) return;
    isLoadingSchedules = true;
    schedulesError = null;
    notifyListeners();

    _schedulesSub?.cancel();

    final stream = isTeacherOrHead
        ? _service.streamSchedulesForTeacher(teacherUid: uid)
        : _service.streamSchedulesForStudent(role: role, uid: uid);

    _schedulesSub = stream.listen((schedules) {
      todaySchedules = schedules;
      schedulesError = null;
      if (isLoadingSchedules) {
        isLoadingSchedules = false;
      }
      if (hasListeners) notifyListeners();
    }, onError: (e, s) {
      debugPrint("[HomeController] CRITICAL ERROR during schedule streaming: $e\n$s");
      schedulesError = e.toString();
      todaySchedules = const [];
      isLoadingSchedules = false;
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> refreshToday() async {
    // Re-initialize the stream for a manual refresh.
    initTodaySchedulesRealtime();
  }

  // ----------------------- Chip Actions -----------------------

  Future<InstructorDetails?> viewInstructorDetails(String instructorId) async {
    _instructorDetails = await _service.fetchInstructorDetails(instructorId);
    return _instructorDetails;
  }

  Future<List<SectionStudent>?> viewSectionRoster(String sectionName) async {
    _sectionRoster = await _service.fetchStudentsForSection(sectionName);
    return _sectionRoster;
  }

  // **THE FIX**: Pass today's date to the service.
  Future<List<ScheduleItem>?> viewRoomSchedule(String roomName) async {
    _roomSchedule = await _service.fetchSchedulesForRoom(roomName: roomName, forDate: DateTime.now());
    return _roomSchedule;
  }

  // ----------------------- Notes actions -----------------------

  Future<void> saveNote(BuildContext context, String text) async {
    final newText = text.trim();
    await _service.saveNote(role: role, uid: uid, text: newText);
    noteText = newText.isNotEmpty ? newText : 'Tap to write notes';
    notifyListeners();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved')),
      );
    }
  }

  Future<void> resetNote(BuildContext context) async {
    await _service.resetNote(role: role, uid: uid);
    noteText = 'Tap to write notes';
    notifyListeners();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note reset successfully')),
      );
    }
  }

  @protected
  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _unreadSub?.cancel();
    _schedulesSub?.cancel();
    super.dispose();
  }

  // ----------------------- Helpers -----------------------

  String _toAcronym(String input, {bool removeStopWords = true, int? maxLetters}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final stop = {'and','of','for','in','on','the','&','at','a'};
    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .where((w) => !removeStopWords || !stop.contains(w.toLowerCase()))
        .map((w) => w[0].toUpperCase())
        .toList();

    if (words.isEmpty) return '';
    final joined = words.join();
    if (maxLetters != null && maxLetters > 0 && joined.length > maxLetters) {
      return joined.substring(0, maxLetters);
    }
    return joined;
  }
}