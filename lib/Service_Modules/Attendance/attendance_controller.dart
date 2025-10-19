import 'package:flutter/material.dart';
import 'attendance_service.dart';

// These UI-specific models remain here as they are only used by the Attendance UI.
enum ViewMode { daily, weekly, monthly }

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

class AttendanceStatusCounts {
  final int present;
  final int late;
  final int absent;
  final int excused;

  const AttendanceStatusCounts({
    this.present = 0,
    this.late = 0,
    this.absent = 0,
    this.excused = 0,
  });

  int get total => present + late + absent + excused;

  AttendanceStatusCounts copyWith({
    int? present,
    int? late,
    int? absent,
    int? excused,
  }) {
    return AttendanceStatusCounts(
      present: present ?? this.present,
      late: late ?? this.late,
      absent: absent ?? this.absent,
      excused: excused ?? this.excused,
    );
  }
}

class AttendanceState {
  final ViewMode mode;
  final DateTime anchor;
  final ActiveTerm? activeTerm;
  final List<SubjectDayGroup> dailyGroups;
  final List<SubjectWeekItem> weeklyItems;
  final List<SubjectTotals> monthlyTotals;
  final bool loading;
  final String? error;
  final AttendanceStatusCounts statusCounts;
  final List<Session>? filteredSessions; // For showing sessions by status
  final AttendanceStatus? selectedStatus; // Currently selected status filter

  const AttendanceState({
    required this.mode,
    required this.anchor,
    this.activeTerm,
    required this.dailyGroups,
    required this.weeklyItems,
    required this.monthlyTotals,
    required this.loading,
    required this.error,
    required this.statusCounts,
    this.filteredSessions,
    this.selectedStatus,
  });

  AttendanceState copyWith({
    ViewMode? mode,
    DateTime? anchor,
    ActiveTerm? activeTerm,
    List<SubjectDayGroup>? dailyGroups,
    List<SubjectWeekItem>? weeklyItems,
    List<SubjectTotals>? monthlyTotals,
    bool? loading,
    Object? error = const _NoChange<String?>(),
    AttendanceStatusCounts? statusCounts,
    Object? filteredSessions = const _NoChange<List<Session>?>(),
    Object? selectedStatus = const _NoChange<AttendanceStatus?>(),
  }) {
    return AttendanceState(
      mode: mode ?? this.mode,
      anchor: anchor ?? this.anchor,
      activeTerm: activeTerm ?? this.activeTerm,
      dailyGroups: dailyGroups ?? this.dailyGroups,
      weeklyItems: weeklyItems ?? this.weeklyItems,
      monthlyTotals: monthlyTotals ?? this.monthlyTotals,
      loading: loading ?? this.loading,
      error: error is _NoChange ? this.error : error as String?,
      statusCounts: statusCounts ?? this.statusCounts,
      filteredSessions: filteredSessions is _NoChange ? this.filteredSessions : filteredSessions as List<Session>?,
      selectedStatus: selectedStatus is _NoChange ? this.selectedStatus : selectedStatus as AttendanceStatus?,
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
    statusCounts: const AttendanceStatusCounts(),
    filteredSessions: null,
    selectedStatus: null,
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
    final term = state.activeTerm;
    if (term == null) return false; // Cannot shift if we don't know the term boundaries.

    // final currentAnchor = _dateOnly(state.anchor);
    final termEnd = _dateOnly(term.endDate);

    // NEW: If the current view is already at or past the end date, disable the button.
    // if (currentAnchor.isAfter(termEnd) || currentAnchor == termEnd) {
    //   return false;
    // }

    // Original logic to prevent going past tomorrow, capped by term end
    final now = DateTime.now();
    DateTime boundary = _dateOnly(now).add(const Duration(days: 1));
    if (termEnd.isBefore(boundary)) {
      boundary = termEnd;
    }

    switch (state.mode) {
      case ViewMode.daily:
        return _dateOnly(state.anchor).isBefore(boundary);
      case ViewMode.weekly:
        final startOfNextWeek = _startOfWeek(state.anchor).add(const Duration(days: 7));
        return !startOfNextWeek.isAfter(boundary);
      case ViewMode.monthly:
        final startOfNextMonth = DateTime(state.anchor.year, state.anchor.month + 1, 1);
        return !startOfNextMonth.isAfter(boundary);
    }
  }

  bool get canShiftPrev {
    final term = state.activeTerm;
    if (term == null) return false;

    // For Daily view: Allow viewing at least the past 30 days
    if (state.mode == ViewMode.daily) {
      final thirtyDaysAgo = _dateOnly(DateTime.now()).subtract(const Duration(days: 30));
      final earliestAllowed = _dateOnly(term.startDate).isAfter(thirtyDaysAgo)
          ? thirtyDaysAgo
          : _dateOnly(term.startDate);

      return _dateOnly(state.anchor).isAfter(earliestAllowed);
    }

    // For other views: Keep the original term boundary logic
    // final currentAnchor = _dateOnly(state.anchor);
    final termStart = _dateOnly(term.startDate);

    switch (state.mode) {
      case ViewMode.weekly:
        return _startOfWeek(state.anchor).isAfter(_startOfWeek(termStart));
      case ViewMode.monthly:
        return _startOfMonth(state.anchor).isAfter(_startOfMonth(termStart));
      default:
        return false; // Should not reach here
    }
  }

  // bool get canShiftPrev {
  //   final term = state.activeTerm;
  //   if (term == null) return false; // Cannot shift if we don't know the term boundaries.
  //
  //   final currentAnchor = _dateOnly(state.anchor);
  //   final termStart = _dateOnly(term.endDate);
  //
  //   // // NEW: If the current view is already at or before the start date, disable the button.
  //   if (currentAnchor.isBefore(termStart) || currentAnchor == termStart) {
  //      return false;
  //    }
  //
  //   // Original logic to check against the start boundary
  //   switch (state.mode) {
  //     case ViewMode.daily:
  //       return _dateOnly(state.anchor).isAfter(termStart);
  //     case ViewMode.weekly:
  //       return _startOfWeek(state.anchor).isAfter(_startOfWeek(termStart));
  //     case ViewMode.monthly:
  //       return _startOfMonth(state.anchor).isAfter(_startOfMonth(termStart));
  //   }
  // }

  void setMode(ViewMode m) {
    _state = _state.copyWith(
        mode: m,
        anchor: _dateOnly(_state.anchor),
        selectedStatus: null,
        filteredSessions: null
    );
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
    _state = _state.copyWith(
        anchor: _dateOnly(a),
        selectedStatus: null,
        filteredSessions: null
    );
    refresh();
  }

  void jumpToDate(DateTime date) {
    _state = _state.copyWith(
        anchor: _dateOnly(date),
        selectedStatus: null,
        filteredSessions: null
    );
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
        final tomorrow = _dateOnly(DateTime.now()).add(const Duration(days: 1));
        if (_dateOnly(s) == tomorrow) {
          return "Tomorrow";
        }
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

  // New method to filter sessions by attendance status
  Future<void> filterByStatus(AttendanceStatus status) async {
    _state = _state.copyWith(loading: true);
    notifyListeners();

    try {
      final sessions = await service.getSessionsByStatus(
        userId: userId,
        role: role,
        status: status,
        date: _state.anchor,
      );

      debugPrint('[FILTER] Filtering for status: ${status.name}');
      debugPrint('[FILTER] Found ${sessions.length} matching sessions');

      for (final session in sessions) {
        debugPrint('[FILTER] Matching session: ${session.subject}');
      }

      _state = _state.copyWith(
        filteredSessions: sessions,
        selectedStatus: status,
        loading: false,
      );
    } catch (e) {
      _state = _state.copyWith(
        error: "Failed to filter sessions: ${e.toString()}",
        loading: false,
      );
    }

    notifyListeners();
  }

  void clearFilter() {
    _state = _state.copyWith(
      filteredSessions: null,
      selectedStatus: null,
    );
    notifyListeners();
  }

  Future<void> refresh() async {
    _state = _state.copyWith(loading: true, error: null);
    notifyListeners();

    try {

      // We make a lightweight call to the service if the term isn't already in the state.
      final currentactiveTerm = _state.activeTerm ?? await service.getSessionsForRange(
        userId: userId, role: role, start: DateTime.now(), end: DateTime.now(),
      ).then((res) => res.$2);

      final (DateTime start, DateTime end) = switch (state.mode) {
        ViewMode.daily   => (_startOfDay(state.anchor), _endOfDay(state.anchor)),
        ViewMode.weekly  => (_startOfWeek(state.anchor), _endOfWeek(state.anchor)),
        ViewMode.monthly => (_startOfMonth(state.anchor), _endOfMonth(state.anchor)),
      };

      final (sessionsByDate, termFromService) = await service.getSessionsForRange(
        userId: userId, role: role, start: start, end: end,
      );

      // Calculate attendance status counts
      var statusCounts = const AttendanceStatusCounts();
      for (final sessions in sessionsByDate.values) {
        for (final session in sessions) {
          switch (session.status) {
            case AttendanceStatus.present:
              statusCounts = statusCounts.copyWith(present: statusCounts.present + 1);
              break;
            case AttendanceStatus.late:
              statusCounts = statusCounts.copyWith(late: statusCounts.late + 1);
              break;
            case AttendanceStatus.absent:
              statusCounts = statusCounts.copyWith(absent: statusCounts.absent + 1);
              break;
            case AttendanceStatus.excused:
              statusCounts = statusCounts.copyWith(excused: statusCounts.excused + 1);
              break;
            default:
              break;
          }
        }
      }

      List<SubjectDayGroup> dailyGroups = const [];
      if (state.mode == ViewMode.daily) {
        final d = _startOfDay(state.anchor);
        final list = sessionsByDate[d] ?? const <Session>[];
        final map = <String, List<Session>>{};
        for (final s in list) {
          map.putIfAbsent(_getSubjectDisplayKey(s), () => []).add(s);
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
          if (date.weekday > 5) return;
          for (final s in sessions) {
            bySubject.putIfAbsent(_getSubjectDisplayKey(s), () => {})[date.weekday] = s;
          }
        });

        weeklyItems = bySubject.entries.map((entry) {
          final statuses = List<AttendanceStatus?>.filled(5, null);
          for (int i = 1; i <= 5; i++) {
            if (entry.value.containsKey(i)) {
              statuses[i-1] = entry.value[i]!.status;
            }
          }
          final attendedCount = statuses.where((s) => s == AttendanceStatus.present || s == AttendanceStatus.excused).length;
          return SubjectWeekItem(
            subjectDisplay: entry.key,
            attended: attendedCount,
            total: entry.value.length,
            statuses: statuses,
          );
        }).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      List<SubjectTotals> monthlyTotals = const [];
      if (state.mode == ViewMode.monthly) {
        final map = <String, List<Session>>{};
        sessionsByDate.values.expand((s) => s).forEach((s) {
          map.putIfAbsent(_getSubjectDisplayKey(s), () => []).add(s);
        });
        monthlyTotals = map.entries.map((e) {
          final attendedCount = e.value.where((s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.excused).length;
          return SubjectTotals(
            subjectDisplay: e.key,
            attended: attendedCount,
            total: e.value.length,
          );
        }).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));
      }

      _state = _state.copyWith(
        activeTerm: termFromService ?? currentactiveTerm,
        dailyGroups: dailyGroups,
        weeklyItems: weeklyItems,
        monthlyTotals: monthlyTotals,
        statusCounts: statusCounts,
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