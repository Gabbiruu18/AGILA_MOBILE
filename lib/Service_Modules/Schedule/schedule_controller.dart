import 'package:flutter/foundation.dart';
import 'schedule_service.dart';

enum ViewMode { today, week }

class ScheduleController extends ChangeNotifier {
  final ScheduleService service;
  final String uid;
  final String role;

  ViewMode mode = ViewMode.today;
  int dayOffset = 0;

  bool isLoading = false;
  String? error;

  Map<int, List<Session>> weekItems = const {};
  List<Session> dayItems = const [];

  ScheduleController({
    required this.service,
    required this.uid,
    required this.role,
  }) {
    debugPrint("[ScheduleController] Initializing for user '$uid' with role '$role'");
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
    debugPrint("[ScheduleController] Loading schedules...");
    try {
      weekItems = await service.fetchWeek(uid: uid, role: role);
      debugPrint("[ScheduleController] Successfully loaded ${weekItems.values.expand((e) => e).length} total sessions for the week.");
      _filterDayItems();
    } catch (e, s) {
      error = e.toString();
      weekItems = {};
      dayItems = [];
      debugPrint("[ScheduleController] CRITICAL ERROR loading schedules: $e\n$s");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _filterDayItems() {
    final weekday = dayDate.weekday;
    dayItems = weekItems[weekday] ?? [];
    debugPrint("[ScheduleController] Filtered for day ${dayDate.toString().split(' ')[0]}. Found ${dayItems.length} sessions.");
    notifyListeners();
  }

  Future<void> setMode(ViewMode v) async {
    if (mode == v) return;
    mode = v;
    debugPrint("[ScheduleController] Mode changed to: $v");
    notifyListeners();
  }

  void stepDay(int delta) {
    final next = (dayOffset + delta).clamp(0, 1);
    if (next == dayOffset) return;
    dayOffset = next;
    debugPrint("[ScheduleController] Day offset changed to: $dayOffset");
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

  Future<List<SectionStudent>> viewSectionRoster(String sectionName) {
    debugPrint("[ScheduleController] Fetching roster for section: '$sectionName'");
    return service.fetchStudentsForSection(sectionName: sectionName);
  }

  // **THE CHANGE**: Add a date parameter and pass it to the service.
  Future<List<RoomSchedule>> viewRoomSchedule({required String roomName, required DateTime forDate}) {
    debugPrint("[ScheduleController] Fetching schedule for room: '$roomName' for date: $forDate");
    return service.fetchSchedulesForRoom(roomName: roomName, forDate: forDate);
  }
}