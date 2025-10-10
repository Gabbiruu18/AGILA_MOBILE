import 'package:flutter/material.dart';
import 'attendance_service.dart';

class AttendanceState {
  final ViewMode mode;
  final DateTime anchor;
  final List<SubjectDayGroup> dailyGroups;
  final List<SubjectWeekItem> weeklyItems;
  final List<SubjectTotals> monthlyTotals;
  final bool loading;
  final String? error;

  const AttendanceState({
    required this.mode,
    required this.anchor,
    required this.dailyGroups,
    required this.weeklyItems,
    required this.monthlyTotals,
    required this.loading,
    required this.error,
  });

  AttendanceState copyWith({
    ViewMode? mode,
    DateTime? anchor,
    List<SubjectDayGroup>? dailyGroups,
    List<SubjectWeekItem>? weeklyItems,
    List<SubjectTotals>? monthlyTotals,
    bool? loading,
    Object? error = const _NoChange<String?>(),
  }) {
    return AttendanceState(
      mode: mode ?? this.mode,
      anchor: anchor ?? this.anchor,
      dailyGroups: dailyGroups ?? this.dailyGroups,
      weeklyItems: weeklyItems ?? this.weeklyItems,
      monthlyTotals: monthlyTotals ?? this.monthlyTotals,
      loading: loading ?? this.loading,
      error: error is _NoChange ? this.error : error as String?,
    );
  }

  static AttendanceState initial(DateTime now) => AttendanceState(
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

class AttendanceController extends ChangeNotifier {
  final AttendanceService service;
  final String userId;
  final String role;
  AttendanceState _state = AttendanceState.initial(DateTime.now());
  AttendanceState get state => _state;

  AttendanceController({required this.service, required this.userId, required this.role});

  // --- Date Helpers ---
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _startOfDay(DateTime d) => _dateOnly(d);
  DateTime _startOfWeek(DateTime d) => _dateOnly(d).subtract(Duration(days: d.weekday - 1));
  DateTime _endOfWeek(DateTime d) => _startOfWeek(d).add(const Duration(days: 6));
  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

  // --- Navigation Properties ---
  bool get isToday => _dateOnly(state.anchor) == _dateOnly(DateTime.now());

  bool get canShiftNext {
    final now = DateTime.now();
    switch (state.mode) {
      case ViewMode.daily:
      // Allow shifting to tomorrow, but not beyond.
        return _dateOnly(state.anchor).isBefore(_dateOnly(now).add(const Duration(days: 1)));
      case ViewMode.weekly:
      // Do not allow shifting to a future week.
        return !_startOfWeek(state.anchor.add(const Duration(days: 7))).isAfter(_startOfWeek(now));
      case ViewMode.monthly:
      // Do not allow shifting to a future month.
        final nextMonth = _startOfMonth(state.anchor).add(const Duration(days: 32));
        return !_startOfMonth(nextMonth).isAfter(_startOfMonth(now));
    }
  }

  // --- Navigation Actions ---
  void setMode(ViewMode m) {
    _state = _state.copyWith(mode: m, anchor: _dateOnly(_state.anchor));
    refresh();
  }

  void shiftPeriod(int delta) {
    if (delta > 0 && !canShiftNext) return;

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
        if (_dateOnly(s) == _dateOnly(DateTime.now()).add(const Duration(days: 1))) return "Tomorrow";
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

  Future<void> refresh() async {
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();

    try {
      final (DateTime start, DateTime end) = switch (state.mode) {
        ViewMode.daily   => (_startOfDay(state.anchor), _startOfDay(state.anchor)),
        ViewMode.weekly  => (_startOfWeek(state.anchor), _endOfWeek(state.anchor)),
        ViewMode.monthly => (_startOfMonth(state.anchor), _endOfMonth(state.anchor)),
      };

      final sessionsByDate = await service.getSessionsForRange(
        userId: userId, role: role, start: start, end: end,
      );

      // ---- Daily groups (for anchor date)
      List<SubjectDayGroup> dailyGroups = const [];
      if (state.mode == ViewMode.daily) {
        final d = _startOfDay(state.anchor);
        final list = sessionsByDate[d] ?? const <Session>[];
        final map = <String, List<Session>>{};
        for (final s in list) {
          map.putIfAbsent(displayName(s), () => []).add(s);
        }
        dailyGroups = map.entries.map((e) {
          e.value.sort((a, b) => a.start.hour.compareTo(b.start.hour));
          return SubjectDayGroup(subjectDisplay: e.key, sessions: e.value);
        }).toList()
          ..sort((a, b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      // ---- Weekly items (Mon–Fri)
      List<SubjectWeekItem> weeklyItems = const [];
      if (state.mode == ViewMode.weekly) {
        final mon = _startOfWeek(state.anchor);
        final byKey = <String, List<(int idx, Session s)>>{};
        for (int i = 0; i < 5; i++) { // Only Mon-Fri
          final d = mon.add(Duration(days: i));
          for (final s in sessionsByDate[d] ?? []) {
            byKey.putIfAbsent(displayName(s), () => [])!.add((i, s));
          }
        }
        weeklyItems = byKey.entries.map((entry) {
          final statuses = List<SessStatus?>.filled(5, null);
          for (final pair in entry.value) {
            statuses[pair.$1] = SessStatus.scheduled; // Mark as scheduled
          }
          final total = entry.value.length;
          return SubjectWeekItem(
            subjectDisplay: entry.key,
            week: List<bool>.generate(5, (i) => statuses[i] != null),
            attended: 0, // Placeholder
            total: total,
            statuses: statuses,
          );
        }).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      // ---- Monthly totals
      List<SubjectTotals> monthlyTotals = const [];
      if (state.mode == ViewMode.monthly) {
        final map = <String, int>{};
        sessionsByDate.values.expand((s) => s).forEach((s) {
          map[displayName(s)] = (map[displayName(s)] ?? 0) + 1;
        });
        monthlyTotals = map.entries.map((e) => SubjectTotals(
          subjectDisplay: e.key,
          attended: 0, // Placeholder
          total: e.value,
        )).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      _state = _state.copyWith(
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

  // --- Methods for Details Panel ---
  Future<List<SectionStudent>> viewSectionRoster(String sectionName) {
    return service.fetchStudentsForSection(sectionName: sectionName);
  }

  Future<InstructorDetails?> viewInstructorDetails(String instructorId) {
    return service.fetchInstructorDetails(instructorId: instructorId);
  }
}