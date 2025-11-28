import 'package:flutter/material.dart';
import 'attendance_service.dart';

enum ViewMode { daily, weekly, monthly }

class SubjectDayGroup {
  final String subjectDisplay;
  final List<Session> sessions;
  const SubjectDayGroup({required this.subjectDisplay, required this.sessions});
}

class SubjectWeekItem {
  final String subjectDisplay;
  final Map<int, Map<String, AttendanceStatus>> sessionStatuses;
  final int attended;
  final int total;

  const SubjectWeekItem({
    required this.subjectDisplay,
    required this.sessionStatuses,
    required this.attended,
    required this.total,
  });

  // Helper method to get statuses for a specific room type
  List<AttendanceStatus?> getStatusesForRoomType(String roomType) {
    final statuses = List<AttendanceStatus?>.filled(5, null);
    for (int i = 1; i <= 5; i++) {
      if (sessionStatuses.containsKey(i) && sessionStatuses[i]!.containsKey(roomType)) {
        statuses[i-1] = sessionStatuses[i]![roomType];
      }
    }
    return statuses;
  }
  // Get all room types for this subject
  List<String> get roomTypes {
    final types = <String>{};
    for (final weekday in sessionStatuses.keys) {
      types.addAll(sessionStatuses[weekday]!.keys);
    }
    return types.toList();
  }
}

class SubjectTotals {
  final String subjectDisplay;
  final String roomType;
  final int attended;
  final int total;

  const SubjectTotals({
    required this.subjectDisplay,
    required this.roomType,
    required this.attended,
    required this.total,
  });
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
  final List<Session>? filteredSessions;
  final AttendanceStatus? selectedStatus;
  final List<Session> weeklyDetails;
  final List<Session> monthlyDetails;

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
    required this.weeklyDetails,
    required this.monthlyDetails,
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
    List<Session>? weeklyDetails,
    List<Session>? monthlyDetails,
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
      weeklyDetails: weeklyDetails ?? this.weeklyDetails,
      monthlyDetails: monthlyDetails ?? this.monthlyDetails,
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
    weeklyDetails: const [],
    monthlyDetails: const [],
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
    if (term == null) return false;

    // final currentAnchor = _dateOnly(state.anchor);
    final termEnd = _dateOnly(term.endDate);

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

    //Allow viewing at least the past 30 days
    if (state.mode == ViewMode.daily) {
      final thirtyDaysAgo = _dateOnly(DateTime.now()).subtract(const Duration(days: 30));
      final earliestAllowed = _dateOnly(term.startDate).isAfter(thirtyDaysAgo)
          ? thirtyDaysAgo
          : _dateOnly(term.startDate);

      return _dateOnly(state.anchor).isAfter(earliestAllowed);
    }

    final termStart = _dateOnly(term.startDate);

    switch (state.mode) {
      case ViewMode.weekly:
        return _startOfWeek(state.anchor).isAfter(_startOfWeek(termStart));
      case ViewMode.monthly:
        return _startOfMonth(state.anchor).isAfter(_startOfMonth(termStart));
      default:
        return false;
    }
  }

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
      List<SubjectWeekItem> weeklyItems = const [];
      List<SubjectTotals> monthlyTotals = const [];
      List<Session> weeklyDetails = const [];
      List<Session> monthlyDetails = const [];

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
      } else if (state.mode == ViewMode.weekly) {
        final bySubject = <String, Map<int, Map<String, Session>>>{};

        sessionsByDate.forEach((date, sessions) {
          if (date.weekday > 5) return;
          for (final s in sessions) {
            final subject = s.subject;
            bySubject
                .putIfAbsent(subject, () => {})
                .putIfAbsent(date.weekday, () => {})
            [s.roomType] = s;
          }
        });

        weeklyItems = bySubject.entries.map((entry) {
          final sessionStatuses = <int, Map<String, AttendanceStatus>>{};
          var attendedCount = 0;
          var totalCount = 0;

          for (final weekdayEntry in entry.value.entries) {
            final weekday = weekdayEntry.key;
            for (final roomTypeEntry in weekdayEntry.value.entries) {
              final session = roomTypeEntry.value;

              sessionStatuses.putIfAbsent(weekday, () => {});

              sessionStatuses[weekday]![session.roomType] = session.status;

              if (session.status == AttendanceStatus.present ||
                  session.status == AttendanceStatus.excused) {
                attendedCount++;
              }
              totalCount++;
            }
          }

          return SubjectWeekItem(
            subjectDisplay: entry.key,
            sessionStatuses: sessionStatuses,
            attended: attendedCount,
            total: totalCount,
          );
        }).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));
        weeklyDetails = sessionsByDate.values.expand((s) => s).toList();
      } else if (state.mode == ViewMode.monthly) {
        final map = <String, Map<String, List<Session>>>{};
        sessionsByDate.values.expand((s) => s).forEach((s) {
          map
              .putIfAbsent(s.subject, () => {})
              .putIfAbsent(s.roomType, () => [])
              .add(s);
        });

        final totals = <SubjectTotals>[];
        for (final subjectEntry in map.entries) {
          for (final roomTypeEntry in subjectEntry.value.entries) {
            final sessions = roomTypeEntry.value;
            final attendedCount = sessions.where((s) =>
            s.status == AttendanceStatus.present ||
                s.status == AttendanceStatus.excused
            ).length;

            totals.add(SubjectTotals(
              subjectDisplay: subjectEntry.key,
              roomType: roomTypeEntry.key,
              attended: attendedCount,
              total: sessions.length,
            ));
          }
        }

        monthlyTotals = totals
          ..sort((a, b) {
            final subjectCompare = a.subjectDisplay.compareTo(b.subjectDisplay);
            if (subjectCompare != 0) return subjectCompare;
            return a.roomType.compareTo(b.roomType);
          });
        monthlyDetails = sessionsByDate.values.expand((s) => s).toList();
      }

      _state = _state.copyWith(
        activeTerm: termFromService ?? currentactiveTerm,
        dailyGroups: dailyGroups,
        weeklyItems: weeklyItems,
        monthlyTotals: monthlyTotals,
        statusCounts: statusCounts,
        weeklyDetails: weeklyDetails,
        monthlyDetails: monthlyDetails,
        loading: false,
        error: null,
      );
    } catch (e) {
      _state = _state.copyWith(loading: false, error: e.toString());
    }
    notifyListeners();
  }

  Future<void> updatePastAttendance() async {
    _state = _state.copyWith(loading: true);
    notifyListeners();

    try {
      // Get the active term
      final activeTerm = _state.activeTerm ?? await service.getSessionsForRange(
        userId: userId, role: role, start: DateTime.now(), end: DateTime.now(),
      ).then((res) => res.$2);

      if (activeTerm == null) {
        throw Exception('No active term found');
      }

      // Get all sessions for the term
      final termStart = activeTerm.startDate;
      final now = DateTime.now();
      var currentDate = termStart;
      while (currentDate.isBefore(now)) {
        final endDate = currentDate.add(const Duration(days: 7));
        final endDateCapped = endDate.isAfter(now) ? now : endDate;

        await service.getSessionsForRange(
          userId: userId, role: role, start: currentDate, end: endDateCapped,
        );

        currentDate = endDate;
      }

      _state = _state.copyWith(
        loading: false,
        error: 'Attendance updated successfully',
      );
    } catch (e) {
      _state = _state.copyWith(
        loading: false,
        error: 'Failed to update attendance: ${e.toString()}',
      );
    }

    notifyListeners();
  }

  Future<void> updateMissingAttendance() async {
    _state = _state.copyWith(loading: true);
    notifyListeners();

    try {
      // Get the active term if needed
      final activeTerm = _state.activeTerm ?? await service.getSessionsForRange(
        userId: userId, role: role, start: DateTime.now(), end: DateTime.now(),
      ).then((res) => res.$2);

      if (activeTerm == null) {
        throw Exception('No active term found');
      }

      final (DateTime start, DateTime end) = switch (state.mode) {
        ViewMode.daily => (_startOfDay(state.anchor), _endOfDay(state.anchor)),
        ViewMode.weekly => (_startOfWeek(state.anchor), _endOfWeek(state.anchor)),
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
      List<SubjectWeekItem> weeklyItems = const [];
      List<SubjectTotals> monthlyTotals = const [];
      List<Session> weeklyDetails = const [];
      List<Session> monthlyDetails = const [];

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
      } else if (state.mode == ViewMode.weekly) {
        final bySubject = <String, Map<int, Map<String, Session>>>{};

        sessionsByDate.forEach((date, sessions) {
          if (date.weekday > 5) return;
          for (final s in sessions) {
            final subject = s.subject;
            bySubject
                .putIfAbsent(subject, () => {})
                .putIfAbsent(date.weekday, () => {})
            [s.roomType] = s;
          }
        });

        weeklyItems = bySubject.entries.map((entry) {
          final sessionStatuses = <int, Map<String, AttendanceStatus>>{};
          var attendedCount = 0;
          var totalCount = 0;

          for (final weekdayEntry in entry.value.entries) {
            final weekday = weekdayEntry.key;
            for (final roomTypeEntry in weekdayEntry.value.entries) {
              final session = roomTypeEntry.value;

              sessionStatuses.putIfAbsent(weekday, () => {});
              sessionStatuses[weekday]![session.roomType] = session.status;

              if (session.status == AttendanceStatus.present ||
                  session.status == AttendanceStatus.excused) {
                attendedCount++;
              }
              totalCount++;
            }
          }

          return SubjectWeekItem(
            subjectDisplay: entry.key,
            sessionStatuses: sessionStatuses,
            attended: attendedCount,
            total: totalCount,
          );
        }).toList()..sort((a,b) => a.subjectDisplay.compareTo(b.subjectDisplay));

        weeklyDetails = sessionsByDate.values.expand((s) => s).toList();
      } else if (state.mode == ViewMode.monthly) {
        final map = <String, Map<String, List<Session>>>{};
        sessionsByDate.values.expand((s) => s).forEach((s) {
          map
              .putIfAbsent(s.subject, () => {})
              .putIfAbsent(s.roomType, () => [])
              .add(s);
        });

        final totals = <SubjectTotals>[];
        for (final subjectEntry in map.entries) {
          for (final roomTypeEntry in subjectEntry.value.entries) {
            final sessions = roomTypeEntry.value;
            final attendedCount = sessions.where((s) =>
            s.status == AttendanceStatus.present ||
                s.status == AttendanceStatus.excused
            ).length;

            totals.add(SubjectTotals(
              subjectDisplay: subjectEntry.key,
              roomType: roomTypeEntry.key,
              attended: attendedCount,
              total: sessions.length,
            ));
          }
        }

        monthlyTotals = totals
          ..sort((a, b) {
            final subjectCompare = a.subjectDisplay.compareTo(b.subjectDisplay);
            if (subjectCompare != 0) return subjectCompare;
            return a.roomType.compareTo(b.roomType);
          });

        monthlyDetails = sessionsByDate.values.expand((s) => s).toList();
      }

      _state = _state.copyWith(
        activeTerm: termFromService ?? activeTerm,
        dailyGroups: dailyGroups,
        weeklyItems: weeklyItems,
        monthlyTotals: monthlyTotals,
        statusCounts: statusCounts,
        weeklyDetails: weeklyDetails,
        monthlyDetails: monthlyDetails,
        loading: false,
        error: 'Past session statuses updated successfully',
      );
    } catch (e) {
      _state = _state.copyWith(
        loading: false,
        error: 'Failed to update past sessions: ${e.toString()}',
      );
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