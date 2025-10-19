import 'package:flutter/material.dart';
import 'package:project_agila/Service_Modules/Schedule/schedule_controller.dart';
import 'package:project_agila/Service_Modules/Schedule/schedule_service.dart';
import 'package:project_agila/Service_Modules/Schedule/schedule_UI.dart';
import 'package:shimmer/shimmer.dart';

//import '../../Service_Modules/Attendance/attendance_UI.dart';

class ScheduleScreen extends StatefulWidget {
  final String uid;
  final String role;

  const ScheduleScreen({
    super.key,
    required this.uid,
    required this.role, required String academicYearId, required String semesterId,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final ScheduleController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = ScheduleController(
      service: FirestoreScheduleService(),
      uid: widget.uid,
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

  Future<void> _showDatePicker() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: ctrl.state.anchor,
      firstDate: ctrl.state.activeTerm?.startDate ?? DateTime(2020),
      lastDate: ctrl.state.activeTerm?.endDate ?? DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      ctrl.jumpToDate(selectedDate);
    }
  }

  String _getReportTitle() {
    return switch (ctrl.state.mode) {
      ViewMode.daily => "Today's Report",
      ViewMode.weekly => "This Week's Report",
      ViewMode.monthly => "Monthly Report",
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        elevation: 0,
        title: Text(
          "Schedule",
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
                const Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    StatCard(label: "Present", value: 0, icon: Icons.check_circle, tint: Color(0xFF22A06B)),
                    StatCard(label: "Lates",   value: 0, icon: Icons.schedule,    tint: Color(0xFFCC8A00)),
                    StatCard(label: "Absents", value: 0, icon: Icons.cancel,      tint: Color(0xFFD22D2D)),
                  ],
                ),
                const SizedBox(height: 24),

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
                  const LinedTitle("Today’s Subjects"),
                  const SizedBox(height: 12),
                  DailyListScheduleLike(
                    groups: ctrl.state.dailyGroups,
                    onViewDetails: _viewSessionDetails,
                  ),
                ] else if (ctrl.state.mode == ViewMode.weekly) ...[
                  const LinedTitle("This Week’s Subjects"),
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