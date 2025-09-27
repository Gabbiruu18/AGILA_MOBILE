import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project_agila/Service_Modules/Schedule/schedule_controller.dart';
import 'package:project_agila/Service_Modules/Schedule/schedule_service.dart';
import 'package:project_agila/Service_Modules/Schedule/schedule_UI.dart';

class ScheduleScreen extends StatefulWidget {
  final String uid;
  final String role;
  const ScheduleScreen({super.key, required this.uid, required this.role});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final ScheduleController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = ScheduleController(service: FirestoreScheduleService(), uid: widget.uid);
    ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _showRoomSchedule(String roomName) {
    Navigator.of(context).pop();
    _showSlidingPanelWithFuture(
      title: 'Today\'s Schedule for Room $roomName',
      future: ctrl.viewRoomSchedule(roomName),
      builder: (data) => RoomScheduleContent(schedules: data ?? []),
    );
  }

  void _showSlidingPanelWithFuture<T>({
    required String title,
    required Future<T> future,
    required Widget Function(T? data) builder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FutureBuilder<T>(
          future: future,
          builder: (context, snapshot) {
            Widget content;
            if (snapshot.connectionState == ConnectionState.waiting) {
              content = const LoadingContent();
            } else if (snapshot.hasError) {
              content = ErrorContent(error: snapshot.error.toString());
            } else {
              content = builder(snapshot.data);
            }
            return SlidingPanel(title: title, child: content);
          },
        );
      },
    );
  }

  void _viewSession(Session s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _SessionDetailsPanel(
          session: s,
          fetchStudents: () => ctrl.viewSectionRoster(s.section),
          onRoomTap: () => _showRoomSchedule(s.room),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final poppins = Theme.of(context).copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
    );
    return Theme(
      data: poppins,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          elevation: 0,
          title: Text(
            "Schedule",
            style: GoogleFonts.poppins(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            PopupMenuButton<ViewMode>(
              tooltip: "Switch view",
              initialValue: ctrl.mode,
              onSelected: ctrl.setMode,
              itemBuilder: (context) => const [
                PopupMenuItem(value: ViewMode.today, child: Text("Today")),
                PopupMenuItem(value: ViewMode.week, child: Text("Week")),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(ctrl.mode == ViewMode.today ? "Today" : "Week"),
                  Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
                ]),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: ctrl.loadSchedules,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PeriodSwitcher(
                    label: ctrl.mode == ViewMode.today
                        ? (ctrl.dayOffset == 0 ? 'Today' : 'Tomorrow')
                        : 'This Week',
                    showPrev: ctrl.mode == ViewMode.today && ctrl.dayOffset > 0,
                    showNext: ctrl.mode == ViewMode.today && ctrl.dayOffset < 1,
                    onPrev: ctrl.mode == ViewMode.today && ctrl.dayOffset > 0 ? () => ctrl.stepDay(-1) : null,
                    onNext: ctrl.mode == ViewMode.today && ctrl.dayOffset < 1 ? () => ctrl.stepDay(1) : null,
                  ),

                  if (ctrl.isLoading && ctrl.dayItems.isEmpty && ctrl.weekItems.isEmpty)
                    const LinearProgressIndicator(minHeight: 2),

                  if (ctrl.error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ctrl.error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                    ),

                  const SizedBox(height: 8),

                  if (ctrl.mode == ViewMode.today)
                    _TodayView(
                      ctrl: ctrl,
                      onViewDetails: _viewSession,
                    )
                  else
                    _WeekView(
                      ctrl: ctrl,
                      onViewDetails: _viewSession,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayView extends StatelessWidget {
  final ScheduleController ctrl;
  final void Function(Session session) onViewDetails;

  const _TodayView({required this.ctrl, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    if (ctrl.isLoading && ctrl.dayItems.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (ctrl.dayItems.isEmpty) {
      return const EmptyState(
        title: 'No classes',
        message: 'Enjoy your day. There are no scheduled classes.',
      );
    }
    return ListView.separated(
      itemCount: ctrl.dayItems.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = ctrl.dayItems[i];
        return SessionCard(
          session: s,
          status: ctrl.statusFor(s),
          onViewDetails: () => onViewDetails(s),
        );
      },
    );
  }
}

class _WeekView extends StatelessWidget {
  final ScheduleController ctrl;
  final void Function(Session session) onViewDetails;

  const _WeekView({required this.ctrl, required this.onViewDetails});

  String _thisWeekDateRangeText() {
    final now = DateTime.now();
    final mon = now.subtract(Duration(days: now.weekday - 1));
    final sun = mon.add(const Duration(days: 6));
    String m3(int n) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][n - 1];
    return '${m3(mon.month)} ${d2(mon.day)} — ${m3(sun.month)} ${d2(sun.day)}';
  }

  @override
  Widget build(BuildContext context) {
    if (ctrl.isLoading && ctrl.weekItems.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (ctrl.weekItems.isEmpty) {
      return const EmptyState(
        title: 'No classes',
        message: 'There are no scheduled classes for you this week.',
      );
    }

    final map = ctrl.weekItems;
    final dates = weekDatesMonToSun(DateTime.now());

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.06))],
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Text(_thisWeekDateRangeText(), textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(7, (i) {
              final day = i + 1; // 1..7
              final items = map[day] ?? <Session>[];
              final date = dates[day]!;
              final isToday = DateTime.now().weekday == day;

              return Container(
                width: 280,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.06))],
                ),
                child: Column(
                  children: [
                    Row(children: [
                      Text('${weekdayLabel(day)} • ${d2(date.day)}/${d2(date.month)}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainer)),
                      if (isToday) ...[const SizedBox(width: 6), const NowDot()],
                    ]),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No sessions'))
                    else
                      ...items.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MiniSessionTile(session: s, isToday: isToday, onTap: () => onViewDetails(s)),
                      )),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SessionDetailsPanel extends StatefulWidget {
  final Session session;
  final Future<List<SectionStudent>> Function() fetchStudents;
  final VoidCallback onRoomTap;

  const _SessionDetailsPanel({
    required this.session,
    required this.fetchStudents,
    required this.onRoomTap,
  });

  @override
  State<_SessionDetailsPanel> createState() => _SessionDetailsPanelState();
}

class _SessionDetailsPanelState extends State<_SessionDetailsPanel> {
  late Future<List<SectionStudent>> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _studentsFuture = widget.fetchStudents();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ListView(
            children: [
              Text(widget.session.subject, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
              const Divider(height: 24),
              _kv('Time', '${d2(widget.session.startMinutes ~/ 60)}:${d2(widget.session.startMinutes % 60)} – ${d2(widget.session.endMinutes ~/ 60)}:${d2(widget.session.endMinutes % 60)}'),
              _kv('Day', weekdayLabel(widget.session.weekday)),
              const SizedBox(height: 16),
              Text("Room", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                // **FIXED**: Using the public `InfoChip` widget.
                child: InfoChip(
                  icon: Icons.meeting_room_outlined,
                  label: widget.session.room,
                  onTap: widget.onRoomTap,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text("Student Roster (${widget.session.section})", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              FutureBuilder<List<SectionStudent>>(
                future: _studentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingContent();
                  }
                  if (snapshot.hasError) {
                    return ErrorContent(error: snapshot.error.toString());
                  }
                  final students = snapshot.data ?? [];
                  if (students.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(child: Text("No students found in this section.")),
                    );
                  }
                  return SectionRosterContent(students: students);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    });
  }
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 90, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
    const SizedBox(width: 8),
    Expanded(child: Text(v)),
  ]),
);