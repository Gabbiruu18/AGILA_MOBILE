import 'package:flutter/material.dart';
import 'attendance_service.dart';

class AttendanceState {
  final ViewMode mode;
  final DateTime anchor;
  final Counts counts;
  final List<SubjectDayGroup> dailyGroups;
  final List<SubjectWeekItem> weeklyItems;
  final List<SubjectTotals> monthlyTotals;
  final bool loading;
  final String? error;

  const AttendanceState({
    required this.mode,
    required this.anchor,
    required this.counts,
    required this.dailyGroups,
    required this.weeklyItems,
    required this.monthlyTotals,
    required this.loading,
    required this.error,
  });

  AttendanceState copyWith({
    ViewMode? mode,
    DateTime? anchor,
    Counts? counts,
    List<SubjectDayGroup>? dailyGroups,
    List<SubjectWeekItem>? weeklyItems,
    List<SubjectTotals>? monthlyTotals,
    bool? loading,
    Object? error = const _NoChange<String?>(), // sentinel stays
  }) {
    return AttendanceState(
      mode: mode ?? this.mode,
      anchor: anchor ?? this.anchor,
      counts: counts ?? this.counts,
      dailyGroups: dailyGroups ?? this.dailyGroups,
      weeklyItems: weeklyItems ?? this.weeklyItems,
      monthlyTotals: monthlyTotals ?? this.monthlyTotals,
      loading: loading ?? this.loading,
      error: error is _NoChange ? this.error : error as String?, // cast to String?
    );
  }

  static AttendanceState initial(DateTime now) => AttendanceState(
    mode: ViewMode.daily,
    anchor: now,
    counts: const Counts(0, 0, 0),
    dailyGroups: const [],
    weeklyItems: const [],
    monthlyTotals: const [],
    loading: false,
    error: null,
  );
}

// helper to allow nullable field no-change in copyWith
class _NoChange<T> {
  const _NoChange();
}

class AttendanceController extends ChangeNotifier {
  final AttendanceService service;
  final String userId;
  AttendanceState _state = AttendanceState.initial(DateTime.now());
  AttendanceState get state => _state;

  AttendanceController({required this.service, required this.userId});

  // ---- Normalize all boundaries to date-only (00:00) ----
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // Period helpers (use date-only consistently)
  DateTime _startOfDay(DateTime d) => _dateOnly(d);

  DateTime _startOfWeek(DateTime d) {
    final sd = _dateOnly(d);
    return sd.subtract(Duration(days: sd.weekday - 1)); // Monday 00:00
  }

  DateTime _endOfWeek(DateTime d) => _startOfWeek(d).add(const Duration(days: 6));

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  DateTime _endOfMonth(DateTime d) =>
      DateTime(d.year, d.month + 1, 1).subtract(const Duration(days: 1));

  void setMode(ViewMode m) {
    // also normalize anchor to avoid stray time components
    _state = _state.copyWith(mode: m, anchor: _dateOnly(_state.anchor));
    refresh();
  }

  void shiftPeriod(int delta) {
    final m = _state.mode;
    DateTime a = _state.anchor;
    switch (m) {
      case ViewMode.daily:
        a = a.add(Duration(days: delta));
        break;
      case ViewMode.weekly:
        a = a.add(Duration(days: 7 * delta));
        break;
      case ViewMode.monthly:
        a = DateTime(a.year, a.month + delta, 1);
        break;
    }
    _state = _state.copyWith(anchor: _dateOnly(a)); // normalize after shift
    refresh();
  }

  String periodLabel() {
    String m3(int m) => ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][m - 1];
    String monthName(int m) => ["January","February","March","April","May","June","July","August","September","October","November","December"][m - 1];
    String d2(int d) => d.toString().padLeft(2, '0');
    String wd3(DateTime d) => ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][d.weekday - 1];

    switch (_state.mode) {
      case ViewMode.daily:
        final s = _startOfDay(_state.anchor);
        return "${wd3(s)}, ${m3(s.month)} ${d2(s.day)}, ${s.year}";
      case ViewMode.weekly:
        final s = _startOfWeek(_state.anchor);
        final e = _endOfWeek(_state.anchor);
        return "${m3(s.month)} ${d2(s.day)} – ${m3(e.month)} ${d2(e.day)}, ${e.year}";
      case ViewMode.monthly:
        final s = _startOfMonth(_state.anchor);
        return "${monthName(s.month)} ${s.year}";
    }
  }

  int _sev(SessStatus st) {
    switch (st) {
      case SessStatus.absent:  return 3;
      case SessStatus.late:    return 2;
      case SessStatus.present: return 1;
      case SessStatus.excused: return 1;
    }
  }

  Future<void> refresh() async {
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();

    try {
      final (DateTime start, DateTime end) = switch (_state.mode) {
        ViewMode.daily   => (_startOfDay(_state.anchor), _startOfDay(_state.anchor)),
        ViewMode.weekly  => (_startOfWeek(_state.anchor), _endOfWeek(_state.anchor)),
        ViewMode.monthly => (_startOfMonth(_state.anchor), _endOfMonth(_state.anchor)),
      };

      final sessionsByDate = await service.getSessionsForRange(
        userId: userId, start: start, end: end,
      );

      // ---- Counts across the period
      int p = 0, l = 0, a = 0;
      for (final entry in sessionsByDate.entries) {
        for (final s in entry.value) {
          final st = await service.getStatusFor(userId: userId, date: entry.key, session: s);
          switch (st) {
            case SessStatus.present: p++; break;
            case SessStatus.late:    l++; break;
            case SessStatus.excused: p++; break;
            case SessStatus.absent:  a++; break;
          }
        }
      }
      final counts = Counts(p, l, a);

      // ---- Daily groups (for anchor date)
      List<SubjectDayGroup> dailyGroups = const [];
      if (_state.mode == ViewMode.daily) {
        final d = _startOfDay(_state.anchor);
        final list = sessionsByDate[d] ?? const <Session>[];
        final map = <String, List<Session>>{};
        for (final s in list) {
          final key = displayName(s);
          map.putIfAbsent(key, () => []).add(s);
        }
        final groups = map.entries.map((e) {
          e.value.sort((a, b) => a.start.hour != b.start.hour
              ? a.start.hour.compareTo(b.start.hour)
              : a.start.minute.compareTo(b.start.minute));
          return SubjectDayGroup(subjectDisplay: e.key, sessions: e.value);
        }).toList()
          ..sort((a, b) => a.subjectDisplay.compareTo(b.subjectDisplay));
        dailyGroups = groups;
      }

      // ---- Weekly items (Mon–Fri of this anchor week)
      List<SubjectWeekItem> weeklyItems = const [];
      {
        final mon = _startOfWeek(_state.anchor);
        final byKey = <String, List<(int idx, Session s)>>{};
        for (int i = 0; i < 5; i++) {
          final d = mon.add(Duration(days: i));
          final list = sessionsByDate[d] ?? const <Session>[];
          for (final s in list) {
            final key = displayName(s);
            byKey.putIfAbsent(key, () => []);
            byKey[key]!.add((i, s));
          }
        }

        final items = <SubjectWeekItem>[];
        for (final entry in byKey.entries) {
          final statuses = List<SessStatus?>.filled(5, null);
          int attended = 0;
          for (final pair in entry.value) {
            final idx = pair.$1;
            final date = mon.add(Duration(days: idx));
            final st = await service.getStatusFor(userId: userId, date: date, session: pair.$2);

            final cur = statuses[idx];
            if (cur == null || _sev(st) > _sev(cur)) {
              statuses[idx] = st;
            }
            if (st == SessStatus.present || st == SessStatus.late || st == SessStatus.excused) {
              attended++;
            }
          }
          final weekFlags = List<bool>.generate(5, (i) => statuses[i] != null);
          final total = entry.value.length;
          items.add(SubjectWeekItem(
            subjectDisplay: entry.key,
            week: weekFlags,
            attended: attended,
            total: total,
            statuses: statuses,
          ));
        }
        items.sort((a, b) => a.subjectDisplay.compareTo(b.subjectDisplay));
        weeklyItems = items;
      }

      // ---- Monthly totals (actual)
      List<SubjectTotals> monthlyTotals = const [];
      {
        final map = <String, (int att, int tot)>{};
        for (final entry in sessionsByDate.entries) {
          for (final s in entry.value) {
            final name = displayName(s);
            final st = await service.getStatusFor(userId: userId, date: entry.key, session: s);
            final cur = map[name] ?? (0, 0);
            final attInc = (st == SessStatus.present || st == SessStatus.late || st == SessStatus.excused) ? 1 : 0;
            map[name] = (cur.$1 + attInc, cur.$2 + 1);
          }
        }
        final list = map.entries
            .map((e) => SubjectTotals(subjectDisplay: e.key, attended: e.value.$1, total: e.value.$2))
            .toList()
          ..sort((a, b) => a.subjectDisplay.compareTo(b.subjectDisplay));
        monthlyTotals = list;
      }

      _state = _state.copyWith(
        counts: counts,
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
}
