import 'package:flutter/foundation.dart';
import 'schedule_service.dart';

enum ViewMode { today, week }

class ScheduleController extends ChangeNotifier {
  final ScheduleService service;
  final String uid;

  ViewMode mode = ViewMode.today;
  int dayOffset = 0; // 0=Today, 1=Tomorrow

  bool loadingDay = false;
  bool loadingWeek = false;
  String? error;

  List<Session> dayItems = const [];
  Map<int, List<Session>> weekItems = const {};

  ScheduleController({required this.service, required this.uid}) {
    _init();
  }

  Future<void> _init() async {
    await Future.wait([loadDay(), loadWeek()]);
  }

  DateTime get dayDate => DateTime.now().add(Duration(days: dayOffset));

  Future<void> setMode(ViewMode v) async {
    if (mode == v) return;
    mode = v;
    notifyListeners();
    if (mode == ViewMode.today && dayItems.isEmpty) await loadDay();
    if (mode == ViewMode.week && weekItems.isEmpty) await loadWeek();
  }

  void stepDay(int delta) {
    final next = (dayOffset + delta).clamp(0, 1);
    if (next == dayOffset) return;
    dayOffset = next;
    notifyListeners();
    loadDay();
  }

  Future<void> loadDay() async {
    loadingDay = true;
    error = null;
    notifyListeners();
    try {
      dayItems = await service.fetchDay(uid: uid, day: dayDate);
    } catch (e) {
      error = e.toString();
    } finally {
      loadingDay = false;
      notifyListeners();
    }
  }

  Future<void> loadWeek() async {
    loadingWeek = true;
    error = null;
    notifyListeners();
    try {
      weekItems = await service.fetchWeek(uid: uid, anyDayInWeek: DateTime.now());
    } catch (e) {
      error = e.toString();
    } finally {
      loadingWeek = false;
      notifyListeners();
    }
  }

  /// Status logic: for Tomorrow everything is Upcoming
  String statusFor(Session s) {
    if (dayOffset != 0) return 'Upcoming';
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    if (nowMins >= s.startMinutes && nowMins < s.endMinutes) return 'Live';
    if (nowMins < s.startMinutes) return 'Upcoming';
    return 'Done';
  }
}
