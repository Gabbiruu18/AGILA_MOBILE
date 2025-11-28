import 'dart:async';
import 'package:flutter/material.dart';
import 'home_service.dart';
import 'home_UI.dart';

class HomeController extends ChangeNotifier {
  final HomeService _service;
  HomeController({HomeService? service}) : _service = service ?? HomeService();
  bool _isDisposed = false;

  late String role;
  late String uid;
  late String name = '';

  bool get isTeacherOrHead =>
      role == 'teacher' || role == 'program_head';

  String? courseRaw;
  String? departmentRaw;
  String? course;
  String? section;
  String? department;

  String noteText = 'Tap to write notes';
  int unreadCount = 0;
  StreamSubscription<int>? _unreadSub;

  bool isLoading = true;
  bool isLoadingSchedules = false;
  String? schedulesError;

  List<ScheduleItem> todaySchedules = const [];
  StreamSubscription<List<ScheduleItem>>? _schedulesSub;

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
    } catch (e) {
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
      schedulesError = e.toString();
      todaySchedules = const [];
      isLoadingSchedules = false;
      if (hasListeners) notifyListeners();
    });
  }

  Future<void> refreshToday() async {
    initTodaySchedulesRealtime();
  }


  Future<InstructorDetails?> viewInstructorDetails(String instructorId) async {
    _instructorDetails = await _service.fetchInstructorDetails(instructorId);
    return _instructorDetails;
  }

  Future<List<SectionStudent>?> viewSectionRoster(String sectionName) async {
    _sectionRoster = await _service.fetchStudentsForSection(sectionName);
    return _sectionRoster;
  }

  Future<List<ScheduleItem>?> viewRoomSchedule(String roomName) async {
    _roomSchedule = await _service.fetchSchedulesForRoom(roomName: roomName, forDate: DateTime.now());
    return _roomSchedule;
  }


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