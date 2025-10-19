import 'package:flutter/material.dart';
import 'package:project_agila/Service_Modules/Attendance/attendance_controller.dart';
import 'package:project_agila/Service_Modules/Attendance/attendance_UI.dart';
import 'package:project_agila/Service_Modules/Attendance/attendance_service.dart';
import 'package:shimmer/shimmer.dart';

class AttendanceScreen extends StatefulWidget {
  final String uid;
  final String role;

  const AttendanceScreen({super.key, required this.uid, required this.role});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = AttendanceController(
      service: FirestoreAttendanceService(),
      userId: widget.uid,
      role: widget.role,
    )
      ..addListener(() => setState(() {}))
      ..refresh();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _viewSessionDetails(Session session) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SessionDetailsPanel(
          session: session,
          fetchStudents: () => ctrl.viewSectionRoster(session.section, session.id),
          fetchInstructor: () {
            if (session.instructorId.isEmpty) {
              return Future.value(null);
            }
            return ctrl.viewInstructorDetails(session.instructorId);
          }
      ),
    );
  }

  void _showStatusFilterDialog(AttendanceStatus status) {
    if (ctrl.state.mode != ViewMode.daily) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status filtering is only available in daily view"))
      );
      return;
    }

    ctrl.filterByStatus(status).then((_) {
      if (ctrl.state.filteredSessions != null && ctrl.state.filteredSessions!.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => StatusFilterDialog(
            sessions: ctrl.state.filteredSessions!,
            status: status,
            onClose: () {
              ctrl.clearFilter();
              Navigator.of(context).pop();
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No sessions with ${statusText(status).toLowerCase()} status found"))
        );
        ctrl.clearFilter();
      }
    });
  }

  String _getReportTitle() {
    return switch (ctrl.state.mode) {
      ViewMode.daily => "Today's Report",
      ViewMode.weekly => "This Week's Report",
      ViewMode.monthly => "Monthly Report",
    };
  }

  Future<void> _showDatePicker() async {
    // Calculate the earliest date - either term start or 30 days ago
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final termStart = ctrl.state.activeTerm?.startDate ?? DateTime(2020);
    final earliestDate = termStart.isAfter(thirtyDaysAgo) ? thirtyDaysAgo : termStart;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: ctrl.state.anchor,
      firstDate: earliestDate,
      lastDate: ctrl.state.activeTerm?.endDate ?? now.add(const Duration(days: 1)),
    );

    if (selectedDate != null) {
      ctrl.jumpToDate(selectedDate);
    }
  }

  // Future<void> _showDatePicker() async {
  //   final selectedDate = await showDatePicker(
  //     context: context,
  //     initialDate: ctrl.state.anchor,
  //     firstDate: ctrl.state.activeTerm?.startDate ?? DateTime(2020),
  //     lastDate: ctrl.state.activeTerm?.endDate ?? DateTime.now().add(const Duration(days: 1)),
  //   );
  //
  //   if (selectedDate != null) {
  //     ctrl.jumpToDate(selectedDate);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        elevation: 0,
        title: Text(
          "Attendance",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<ViewMode>(
            tooltip: "Switch view",
            initialValue: ctrl.state.mode,
            onSelected: ctrl.setMode,
            itemBuilder: (context) => const [
              PopupMenuItem(value: ViewMode.daily, child: Text("Daily")),
              PopupMenuItem(value: ViewMode.weekly, child: Text("Weekly")),
              PopupMenuItem(value: ViewMode.monthly, child: Text("Monthly")),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(ctrl.state.mode.name[0].toUpperCase() + ctrl.state.mode.name.substring(1)),
                Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
              ]),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ctrl.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EnhancedPeriodSwitcher(
                  label: ctrl.periodLabel(),
                  onPrev: () => ctrl.shiftPeriod(-1),
                  onNext: () => ctrl.shiftPeriod(1),
                  // PASS THE NEW VALUES HERE
                  showPrev: ctrl.canShiftPrev,
                  showNext: ctrl.canShiftNext,
                  onLabelTap: ctrl.state.mode == ViewMode.daily ? _showDatePicker : () {},
                  showTodayButton: ctrl.state.mode == ViewMode.daily && !ctrl.isToday,
                  onTodayTap: ctrl.jumpToToday,
                ),

                if (ctrl.state.error != null)
                // THIS IS THE CORRECTED WIDGET
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // The color is now correctly placed inside the decoration
                      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.error),
                    ),
                    child: Text(ctrl.state.error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                  ),
                const SizedBox(height: 8),

                LinedTitle(_getReportTitle()),
                const SizedBox(height: 12),

                // NEW: 2x2 grid layout for status boxes
                // NEW: 2x2 grid layout for status boxes with reduced height
                Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // First row - Present and Late
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: StatCard(
                              label: "Present",
                              value: ctrl.state.statusCounts.present,
                              icon: Icons.check_circle,
                              tint: const Color(0xFF22A06B),
                              onTap: () => _showStatusFilterDialog(AttendanceStatus.present),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: "Lates",
                              value: ctrl.state.statusCounts.late,
                              icon: Icons.schedule,
                              tint: const Color(0xFFCC8A00),
                              onTap: () => _showStatusFilterDialog(AttendanceStatus.late),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8), // Reduced vertical spacing

                      // Second row - Absent and Excused
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: StatCard(
                              label: "Absents",
                              value: ctrl.state.statusCounts.absent,
                              icon: Icons.cancel,
                              tint: const Color(0xFFD22D2D),
                              onTap: () => _showStatusFilterDialog(AttendanceStatus.absent),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: "Excused",
                              value: ctrl.state.statusCounts.excused,
                              icon: Icons.event_available,
                              tint: const Color(0xFF0096C7),
                              onTap: () => _showStatusFilterDialog(AttendanceStatus.excused),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (ctrl.state.loading)
                  Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LinedTitle("Loading Subjects..."),
                        const SizedBox(height: 12),
                        if (ctrl.state.mode == ViewMode.daily)
                          const DailyListSkeleton()
                        else if (ctrl.state.mode == ViewMode.weekly)
                          const WeeklyListSkeleton()
                        else
                          const MonthlyListSkeleton(),
                      ],
                    ),
                  )
                else if (ctrl.state.mode == ViewMode.daily) ...[
                  const LinedTitle("Today's Subjects"),
                  const SizedBox(height: 12),
                  DailyListScheduleLike(
                    groups: ctrl.state.dailyGroups,
                    onViewDetails: _viewSessionDetails,
                  ),
                ] else if (ctrl.state.mode == ViewMode.weekly) ...[
                  const LinedTitle("This Week's Subjects"),
                  const SizedBox(height: 12),
                  WeeklyList(items: ctrl.state.weeklyItems),
                ] else ...[
                  const LinedTitle("Monthly Totals"),
                  const SizedBox(height: 12),
                  MonthlyList(items: ctrl.state.monthlyTotals),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}