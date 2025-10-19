import 'package:flutter/foundation.dart';
import 'schedule_service.dart';

// ============================ UI-SPECIFIC MODELS (COPIED FROM ATTENDANCE) ============================

// UPDATED: ViewMode now includes monthly
enum ViewMode { daily, weekly, monthly }

// NEW: These classes are copied from the attendance controller to support the new UI.
class SubjectDayGroup {
  final String subjectDisplay;
  final List<Session> sessions;
  const SubjectDayGroup({required this.subjectDisplay, required this.sessions});
}

class SubjectWeekItem {
  final String subjectDisplay;
  final List<AttendanceStatus?> statuses;
  final int attended;
  final int total;
  const SubjectWeekItem({
    required this.subjectDisplay,
    required this.statuses,
    required this.attended,
    required this.total,
  });
}

class SubjectTotals {
  final String subjectDisplay;
  final int attended;
  final int total;
  const SubjectTotals({required this.subjectDisplay, required this.attended, required this.total});
}

// NEW: A comprehensive state class, copied from the attendance controller.
class ScheduleState {
  final ViewMode mode;
  final DateTime anchor;
  final ActiveTerm? activeTerm;
  final List<SubjectDayGroup> dailyGroups;
  final List<SubjectWeekItem> weeklyItems;
  final List<SubjectTotals> monthlyTotals;
  final bool loading;
  final String? error;

  const ScheduleState({
    required this.mode,
    required this.anchor,
    this.activeTerm,
    required this.dailyGroups,
    required this.weeklyItems,
    required this.monthlyTotals,
    required this.loading,
    required this.error,
  });

  ScheduleState copyWith({
    ViewMode? mode,
    DateTime? anchor,
    ActiveTerm? activeTerm,
    List<SubjectDayGroup>? dailyGroups,
    List<SubjectWeekItem>? weeklyItems,
    List<SubjectTotals>? monthlyTotals,
    bool? loading,
    Object? error = const _NoChange<String?>(),
  }) {
    return ScheduleState(
      mode: mode ?? this.mode,
      anchor: anchor ?? this.anchor,
      activeTerm: activeTerm ?? this.activeTerm,
      dailyGroups: dailyGroups ?? this.dailyGroups,
      weeklyItems: weeklyItems ?? this.weeklyItems,
      monthlyTotals: monthlyTotals ?? this.monthlyTotals,
      loading: loading ?? this.loading,
      error: error is _NoChange ? this.error : error as String?,
    );
  }

  static ScheduleState initial(DateTime now) => ScheduleState(
    mode: ViewMode.daily,
    anchor: now,
    dailyGroups: const [],
    weeklyItems: const [],
    monthlyTotals: const [],
    loading: false,
    error: null,
  );
}

class _NoChange<T> { const _NoChange(); }


// ============================ CONTROLLER (HEAVILY UPDATED) ============================

class ScheduleController extends ChangeNotifier {
  final ScheduleService service;
  final String uid;
  final String role;

  ScheduleState _state = ScheduleState.initial(DateTime.now());
  ScheduleState get state => _state;

  ScheduleController({required this.service, required this.uid, required this.role}) {
    refresh();
  }

  // --- Date Helpers ---
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _startOfDay(DateTime d) => _dateOnly(d);
  DateTime _endOfDay(DateTime d) => _dateOnly(d).add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
  DateTime _startOfWeek(DateTime d) => _dateOnly(d).subtract(Duration(days: d.weekday - 1));
  DateTime _endOfWeek(DateTime d) => _startOfWeek(d).add(const Duration(days: 6, hours: 23, minutes: 59));
  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0, 23, 59);

  bool get isToday => _dateOnly(state.anchor) == _dateOnly(DateTime.now());

  // --- Navigation Logic (UPDATED) ---
  bool get canShiftNext {
    final now = DateTime.now();
    switch (state.mode) {
      case ViewMode.daily:
        final tomorrow = _dateOnly(now).add(const Duration(days: 1));
        return _dateOnly(state.anchor).isBefore(tomorrow);
      case ViewMode.weekly:
        final startOfNextWeek = _startOfWeek(now).add(const Duration(days: 7));
        return _startOfWeek(state.anchor).isBefore(startOfNextWeek);
      case ViewMode.monthly:
        final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
        return _startOfMonth(state.anchor).isBefore(startOfNextMonth);
    }
  }

  bool get canShiftPrev {
    final boundary = state.activeTerm?.startDate ?? DateTime(2020);
    switch (state.mode) {
      case ViewMode.daily:
      // NEW: Allow going back to yesterday.
        final yesterday = _dateOnly(DateTime.now()).subtract(const Duration(days: 1));
        return _dateOnly(state.anchor).isAfter(yesterday) && _dateOnly(state.anchor).isAfter(_dateOnly(boundary));
      case ViewMode.weekly:
        final prevWeekStart = _startOfWeek(state.anchor).subtract(const Duration(days: 7));
        return !prevWeekStart.isBefore(_dateOnly(boundary));
      case ViewMode.monthly:
        final currentMonthStart = _startOfMonth(state.anchor);
        return !currentMonthStart.isBefore(_startOfMonth(boundary)) && currentMonthStart != _startOfMonth(boundary);
    }
  }

  // --- State Mutators ---
  void setMode(ViewMode m) {
    _state = _state.copyWith(mode: m, anchor: _dateOnly(state.anchor));
    refresh();
  }

  void shiftPeriod(int delta) {
    if (delta > 0 && !canShiftNext) return;
    if (delta < 0 && !canShiftPrev) return;

    final m = state.mode;
    DateTime a = state.anchor;
    switch (m) {
      case ViewMode.daily:   a = a.add(Duration(days: delta)); break;
      case ViewMode.weekly:  a = a.add(Duration(days: 7 * delta)); break;
      case ViewMode.monthly: a = DateTime(a.year, a.month + delta, 1); break;
    }
    _state = _state.copyWith(anchor: _dateOnly(a));
    refresh();
  }

  void jumpToDate(DateTime date) {
    _state = _state.copyWith(anchor: _dateOnly(date));
    refresh();
  }

  void jumpToToday() {
    jumpToDate(DateTime.now());
  }

  String periodLabel() {
    String m3(int m) => ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][m - 1];
    String monthName(int m) => ["January","February","March","April","May","June","July","August","September","October","November","December"][m - 1];
    String d2(int d) => d.toString().padLeft(2, '0');
    String wd3(DateTime d) => ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][d.weekday - 1];

    switch (state.mode) {
      case ViewMode.daily:
        final s = _startOfDay(state.anchor);
        if (isToday) return "Today";
        final yesterday = _dateOnly(DateTime.now()).subtract(const Duration(days: 1));
        if (_dateOnly(s) == yesterday) return "Yesterday";
        final tomorrow = _dateOnly(DateTime.now()).add(const Duration(days: 1));
        if (_dateOnly(s) == tomorrow) return "Tomorrow";
        return "${wd3(s)}, ${m3(s.month)} ${d2(s.day)}, ${s.year}";
      case ViewMode.weekly:
        final s = _startOfWeek(state.anchor);
        final e = _endOfWeek(state.anchor);
        return "${m3(s.month)} ${d2(s.day)} – ${m3(e.month)} ${d2(e.day)}, ${e.year}";
      case ViewMode.monthly:
        final s = _startOfMonth(state.anchor);
        return "${monthName(s.month)} ${s.year}";
    }
  }

  String _getSubjectDisplayKey(Session session) {
    return '${session.subject} (${session.roomType})';
  }

  // --- Main Data Fetching Logic (REWRITTEN) ---
  Future<void> refresh() async {
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();

    try {
      final (DateTime start, DateTime end) = switch (state.mode) {
        ViewMode.daily   => (_startOfDay(state.anchor), _endOfDay(state.anchor)),
        ViewMode.weekly  => (_startOfWeek(state.anchor), _endOfWeek(state.anchor)),
        ViewMode.monthly => (_startOfMonth(state.anchor), _endOfMonth(state.anchor)),
      };

      final (sessionsByDate, activeTerm) = await service.getSessionsForRange(
        userId: uid, role: role, start: start, end: end,
      );

      // --- Process data for each view mode (copied from attendance) ---
      List<SubjectDayGroup> dailyGroups = const [];
      if (state.mode == ViewMode.daily) {
        final d = _startOfDay(state.anchor);
        final list = sessionsByDate[d] ?? const <Session>[];
        final map = <String, List<Session>>{};
        for (final s in list) { map.putIfAbsent(_getSubjectDisplayKey(s), () => []).add(s); }
        dailyGroups = map.entries.map((e) {
          e.value.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
          return SubjectDayGroup(subjectDisplay: e.key, sessions: e.value);
        }).toList()..sort((a, b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      List<SubjectWeekItem> weeklyItems = const [];
      if (state.mode == ViewMode.weekly) {
        final bySubject = <String, Map<int, Session>>{};
        sessionsByDate.forEach((date, sessions) {
          if (date.weekday > 5) return;
          for (final s in sessions) { bySubject.putIfAbsent(_getSubjectDisplayKey(s), () => {})[date.weekday] = s; }
        });
        weeklyItems = bySubject.entries.map((entry) {
          final statuses = List<AttendanceStatus?>.filled(5, null);
          for (int i = 1; i <= 5; i++) { if (entry.value.containsKey(i)) { statuses[i-1] = entry.value[i]!.status; } }
          final attendedCount = statuses.where((s) => s == AttendanceStatus.present || s == AttendanceStatus.excused).length;
          return SubjectWeekItem(subjectDisplay: entry.key, attended: attendedCount, total: entry.value.length, statuses: statuses);
        }).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      List<SubjectTotals> monthlyTotals = const [];
      if (state.mode == ViewMode.monthly) {
        final map = <String, List<Session>>{};
        sessionsByDate.values.expand((s) => s).forEach((s) { map.putIfAbsent(_getSubjectDisplayKey(s), () => []).add(s); });
        monthlyTotals = map.entries.map((e) {
          final attendedCount = e.value.where((s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.excused).length;
          return SubjectTotals(subjectDisplay: e.key, attended: attendedCount, total: e.value.length);
        }).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      _state = _state.copyWith(
        activeTerm: activeTerm,
        dailyGroups: dailyGroups,
        weeklyItems: weeklyItems,
        monthlyTotals: monthlyTotals,
        loading: false,
        error: null,
      );
    } catch (e) {
      _state = _state.copyWith(loading: false, error: e.toString());
    }
    notifyListeners();
  }

  // --- Detail Fetching Wrappers ---
  Future<List<SectionStudent>> viewSectionRoster(String sectionName, String scheduleId) {
    return service.fetchStudentsForSection(sectionName: sectionName, scheduleId: scheduleId);
  }

  Future<InstructorDetails?> viewInstructorDetails(String instructorId) {
    return service.fetchInstructorDetails(instructorId: instructorId);
  }

  Future<List<RoomSchedule>> viewRoomSchedule({required String roomName, required DateTime forDate}) {
    return service.fetchSchedulesForRoom(roomName: roomName, forDate: forDate);
  }
}