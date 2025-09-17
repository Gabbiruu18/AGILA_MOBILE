import 'dart:async';
import 'package:flutter/material.dart';
import 'home_service.dart';
import 'home_UI.dart';

class HomeController extends ChangeNotifier {
  final HomeService _service;
  HomeController({HomeService? service}) : _service = service ?? HomeService();

  // ---------- Identity ----------
  late String role;
  late String uid;
  late String name;

  // ---------- Display chips / labels ----------
  String? courseRaw;
  String? departmentRaw;
  String? course;       // acronym (e.g., BSIT)
  String? section;      // e.g., "BSIT-4103"
  String? department;   // acronym (e.g., IT)

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

  /// Initialize controller with role/uid/name and load initial data
  Future<void> init({
    required String role,
    required String uid,
    required String name,
  }) async {
    this.role = role;
    this.uid = uid;
    this.name = name;

    isLoading = true;
    notifyListeners();

    try {
      // 1) Load user details for header chips (names only)
      final user = await _service.fetchUserDetails(role: role, uid: uid) ?? {};
      courseRaw     = user['courseName']?.toString();
      departmentRaw = user['departmentName']?.toString();
      section       = user['sectionName']?.toString();

      // Acronyms for compact chips/labels
      course     = _toAcronym(courseRaw ?? '', maxLetters: 4);
      department = _toAcronym(departmentRaw ?? '', maxLetters: 4);

      // 2) Load or create note
      noteText = await _service.getOrCreateNote(role: role, uid: uid);

      // 3) Start unread notifications stream
      _unreadSub?.cancel();
      _unreadSub = _service.streamUnreadCount(role: role, uid: uid).listen((n) {
        unreadCount = n;
        notifyListeners();
      });

      // 4) Load today's schedules (uses `section` doc ID under the hood)
      await initTodaySchedulesAuto();
    } catch (_) {
      // ignore; optional logging
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Loads today's schedules via the `section` doc ID path.
  Future<void> initTodaySchedulesAuto() async {
    if (isLoadingSchedules) return;
    isLoadingSchedules = true;
    schedulesError = null;
    notifyListeners();

    try {
      todaySchedules = await _service.fetchTodaySchedulesForUser(
        role: role,
        uid: uid,
      );
    } catch (e) {
      schedulesError = e.toString();
      todaySchedules = const [];
    } finally {
      isLoadingSchedules = false;
      notifyListeners();
    }
  }

  Future<void> refreshToday() async {
    await initTodaySchedulesAuto();
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

  @override
  void dispose() {
    _unreadSub?.cancel();
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
