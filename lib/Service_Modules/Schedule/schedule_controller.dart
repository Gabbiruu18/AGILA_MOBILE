import 'package:flutter/foundation.dart';
import 'schedule_service.dart';

enum ViewMode { today, week }

class ScheduleController extends ChangeNotifier {
  final ScheduleService service;
  final String uid;

  ViewMode mode = ViewMode.today;
  int dayOffset = 0; // 0=Today, 1=Tomorrow

  bool isLoading = false;
  String? error;

  Map<int, List<Session>> weekItems = const {};
  List<Session> dayItems = const [];

  ScheduleController({required this.service, required this.uid}) {
    _init();
  }

  Future<void> _init() async {
    await loadSchedules();
  }

  DateTime get dayDate => DateTime.now().add(Duration(days: dayOffset));

  Future<void> loadSchedules() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      weekItems = await service.fetchWeek(uid: uid);
      _filterDayItems();
    } catch (e) {
      error = e.toString();
      weekItems = {};
      dayItems = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _filterDayItems() {
    final weekday = dayDate.weekday;
    dayItems = weekItems[weekday] ?? [];
    notifyListeners();
  }

  Future<void> setMode(ViewMode v) async {
    if (mode == v) return;
    mode = v;
    notifyListeners();
  }

  void stepDay(int delta) {
    final next = (dayOffset + delta).clamp(0, 1);
    if (next == dayOffset) return;
    dayOffset = next;
    _filterDayItems();
    notifyListeners();
  }

  String statusFor(Session s) {
    if (dayOffset != 0) return 'Upcoming';
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    if (nowMins >= s.startMinutes && nowMins < s.endMinutes) return 'Live';
    if (nowMins < s.startMinutes) return 'Upcoming';
    return 'Done';
  }

  // Methods to handle chip taps, delegating to the service
  Future<List<SectionStudent>> viewSectionRoster(String sectionName) {
    return service.fetchStudentsForSection(sectionName);
  }

  Future<List<RoomSchedule>> viewRoomSchedule(String roomName) {
    return service.fetchSchedulesForRoom(roomName);
  }
}