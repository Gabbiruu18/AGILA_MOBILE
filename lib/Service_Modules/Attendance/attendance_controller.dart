import 'package:flutter/material.dart';
import 'attendance_service.dart';

// These UI-specific models remain here as they are only used by the Attendance UI.
enum ViewMode { daily, weekly, monthly }
enum SessStatus { scheduled, present, late, absent, excused }

class SubjectDayGroup {
  final String subjectDisplay;
  final List<Session> sessions;
  const SubjectDayGroup({required this.subjectDisplay, required this.sessions});
}

class SubjectWeekItem {
  final String subjectDisplay;
  final List<SessStatus?> statuses;
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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _startOfDay(DateTime d) => _dateOnly(d);
  DateTime _endOfDay(DateTime d) => _dateOnly(d).add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
  DateTime _startOfWeek(DateTime d) => _dateOnly(d).subtract(Duration(days: d.weekday - 1));
  DateTime _endOfWeek(DateTime d) => _startOfWeek(d).add(const Duration(days: 6, hours: 23, minutes: 59));
  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0, 23, 59);

  bool get isToday => _dateOnly(state.anchor) == _dateOnly(DateTime.now());

  bool get canShiftNext {
    final now = DateTime.now();
    switch (state.mode) {
      case ViewMode.daily:
        return _dateOnly(state.anchor).isBefore(_dateOnly(now).add(const Duration(days: 1)));
      case ViewMode.weekly:
        return !_startOfWeek(state.anchor.add(const Duration(days: 7))).isAfter(_startOfWeek(now));
      case ViewMode.monthly:
        final nextMonth = _startOfMonth(state.anchor).add(const Duration(days: 32));
        return !_startOfMonth(nextMonth).isAfter(_startOfMonth(now));
    }
  }

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
        ViewMode.daily   => (_startOfDay(state.anchor), _endOfDay(state.anchor)),
        ViewMode.weekly  => (_startOfWeek(state.anchor), _endOfWeek(state.anchor)),
        ViewMode.monthly => (_startOfMonth(state.anchor), _endOfMonth(state.anchor)),
      };

      final sessionsByDate = await service.getSessionsForRange(
        userId: userId, role: role, start: start, end: end,
      );

      List<SubjectDayGroup> dailyGroups = const [];
      if (state.mode == ViewMode.daily) {
        final d = _startOfDay(state.anchor);
        final list = sessionsByDate[d] ?? const <Session>[];
        final map = <String, List<Session>>{};
        for (final s in list) {
          map.putIfAbsent(s.subject, () => []).add(s);
        }
        dailyGroups = map.entries.map((e) {
          e.value.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
          return SubjectDayGroup(subjectDisplay: e.key, sessions: e.value);
        }).toList()
          ..sort((a, b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      List<SubjectWeekItem> weeklyItems = const [];
      if (state.mode == ViewMode.weekly) {
        final bySubject = <String, Map<int, Session>>{};
        sessionsByDate.forEach((date, sessions) {
          if (date.weekday > 5) return; // Mon-Fri only
          for (final s in sessions) {
            bySubject.putIfAbsent(s.subject, () => {})[date.weekday] = s;
          }
        });

        weeklyItems = bySubject.entries.map((entry) {
          final statuses = List<SessStatus?>.filled(5, null);
          for (int i = 1; i <= 5; i++) { // Weekday 1-5
            if (entry.value.containsKey(i)) {
              statuses[i-1] = SessStatus.scheduled; // Placeholder
            }
          }
          return SubjectWeekItem(
            subjectDisplay: entry.key,
            attended: 0, // Placeholder
            total: entry.value.length,
            statuses: statuses,
          );
        }).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      List<SubjectTotals> monthlyTotals = const [];
      if (state.mode == ViewMode.monthly) {
        final map = <String, int>{};
        sessionsByDate.values.expand((s) => s).forEach((s) {
          map[s.subject] = (map[s.subject] ?? 0) + 1;
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

  Future<List<SectionStudent>> viewSectionRoster(String sectionName, String scheduleId) {
    return service.fetchStudentsForSection(sectionName: sectionName, scheduleId: scheduleId);
  }

  Future<InstructorDetails?> viewInstructorDetails(String instructorId) {
    return service.fetchInstructorDetails(instructorId: instructorId);
  }
}