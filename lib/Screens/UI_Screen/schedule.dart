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
    // Swap to FirestoreScheduleService() once wired:
    ctrl = ScheduleController(service: MockScheduleService(), uid: widget.uid);
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poppins = Theme.of(context).copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
    );
    return Theme(
      data: poppins,
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) {
          // schedule.dart (inside build)

          return Scaffold(
            backgroundColor: kBg, // same tint as Attendance
            appBar: AppBar(
              automaticallyImplyLeading: false,
              centerTitle: false,
              elevation: 0,
              backgroundColor: kBg,
              title: Text(
                "Schedule",
                style: GoogleFonts.poppins(
                  color: kAgilaBlue,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                PopupMenuButton<ViewMode>(
                  tooltip: "Switch view",
                  initialValue: ctrl.mode,
                  color: Color(0xFFFFFFFF),
                  onSelected: ctrl.setMode,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: ViewMode.today, child: Text("Today")),
                    PopupMenuItem(value: ViewMode.week,  child: Text("Week")),
                  ],
                  child: Padding(

                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, color: kAgilaBlue),
                      const SizedBox(width: 4),
                      Text(ctrl.mode == ViewMode.today ? "Today" : "Week"),
                      const Icon(Icons.arrow_drop_down, color: kAgilaBlue),
                    ]),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), // same rhythm as Attendance
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // EXACT same header/nav widget as Attendance
                    // When building the header in your body Column:
                    PeriodSwitcher(
                      label: ctrl.mode == ViewMode.today
                          ? (ctrl.dayOffset == 0 ? 'Today' : 'Tomorrow')
                          : 'This Week',

                      showPrev: ctrl.mode == ViewMode.today && ctrl.dayOffset > 0,
                      showNext: ctrl.mode == ViewMode.today && ctrl.dayOffset < 1,
                      onPrev:  ctrl.mode == ViewMode.today && ctrl.dayOffset > 0 ? () => ctrl.stepDay(-1) : null,
                      onNext:  ctrl.mode == ViewMode.today && ctrl.dayOffset < 1 ? () => ctrl.stepDay(1)  : null,

                      // WEEK mode: both arrows hidden (no navigation)
                    ),


                    if ((ctrl.mode == ViewMode.today && ctrl.loadingDay) ||
                        (ctrl.mode == ViewMode.week  && ctrl.loadingWeek))
                      const LinearProgressIndicator(minHeight: 2),

                    if (ctrl.error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE0E0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB3261E).withOpacity(.25)),
                        ),
                        child: Text(ctrl.error!, style: const TextStyle(color: Color(0xFFB3261E))),
                      ),

                    const SizedBox(height: 8),

                    // ===== Your existing content stays the same below =====
                    if (ctrl.mode == ViewMode.today) ...[
                      if (ctrl.dayItems.isEmpty) ...[
                        const EmptyState(
                          title: 'No classes',
                          message: 'Enjoy your day. (Sundays have no schedule.)',
                        ),
                      ] else ...[
                        ListView.separated(
                          itemCount: ctrl.dayItems.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 8),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final s = ctrl.dayItems[i];
                            final status = ctrl.statusFor(s);
                            return SessionCard(
                              session: s,
                              status: status,
                              onViewDetails: () => _viewSession(context, s),
                            );
                          },
                        ),
                      ],
                    ] else ...[
                      // Small date line below the header, like a lightweight section card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            blurRadius: 10, offset: const Offset(0, 4),
                            color: Colors.black.withOpacity(0.06),
                          )],
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          _thisWeekDateRangeText(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Week(ctrl: ctrl), // your existing week grid/list widget
                    ],
                  ],
                ),
              ),
            ),
          );

        },
      ),
    );
  }

  String _thisWeekDateRangeText() {
    final now = DateTime.now();
    final mon = now.subtract(Duration(days: now.weekday - 1));
    final sun = mon.add(const Duration(days: 6));
    String m3(int n) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][n - 1];
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${m3(mon.month)} ${d2(mon.day)} — ${m3(sun.month)} ${d2(sun.day)}';
  }
}

class _Today extends StatelessWidget {
  final ScheduleController ctrl;
  const _Today({required this.ctrl, super.key});

  @override
  Widget build(BuildContext context) {
    if (ctrl.loadingDay) return const Center(child: CircularProgressIndicator());
    if ((ctrl.error ?? '').isNotEmpty) {
      return Center(child: Text(ctrl.error!, style: const TextStyle(color: Colors.red)));
    }
    if (ctrl.dayItems.isEmpty) {
      return const EmptyState(
        title: 'No classes',
        message: 'Enjoy your day. (Sundays have no schedule.)',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: ctrl.dayItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = ctrl.dayItems[i];
        final status = ctrl.statusFor(s);
        return SessionCard(
          session: s,
          status: status,
          onViewDetails: () => _viewSession(context, s),
        );
      },
    );
  }
}

class _Week extends StatelessWidget {
  final ScheduleController ctrl;
  const _Week({required this.ctrl, super.key});

  @override
  Widget build(BuildContext context) {
    if (ctrl.loadingWeek) return const Center(child: CircularProgressIndicator());
    if ((ctrl.error ?? '').isNotEmpty) {
      return Center(child: Text(ctrl.error!, style: const TextStyle(color: Colors.red)));
    }

    final map = ctrl.weekItems;
    final dates = weekDatesMonToSun(DateTime.now());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(7, (i) {
          final day = i + 1; // 1..7
          final items = map[day] ?? const <Session>[];
          final date = dates[day]!;
          final isToday = DateTime.now().weekday == day;

          return Container(
            width: 280,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.06))],
            ),
            child: Column(
              children: [
                Row(children: [
                  Text('${weekdayLabel(day)} • ${_d2(date.day)}/${_d2(date.month)}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: isToday ? kAgilaBlue : Colors.black87)),
                  if (isToday) ...[const SizedBox(width: 6), const NowDot()],
                ]),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No sessions', style: TextStyle(color: Colors.black45)),
                  )
                else
                  ...items.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MiniSessionTile(
                      session: s,
                      isToday: isToday,
                      onTap: () => _viewSession(context, s),
                    ),
                  )),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// Bottom sheet details (kept simple, UI layer)
void _viewSession(BuildContext context, Session s) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _kv('Section', s.section),
          _kv('Room', s.room),
          _kv('Day', weekdayLabel(s.weekday)),
          _kv('Time',
              '${_d2(s.startMinutes ~/ 60)}:${_d2(s.startMinutes % 60)}'
                  '–${_d2(s.endMinutes ~/ 60)}:${_d2(s.endMinutes % 60)}'),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 90, child: Text(k, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600))),
    const SizedBox(width: 8),
    Expanded(child: Text(v)),
  ]),
);

// Local tiny helper (only used here)
String _d2(int n) => n.toString().padLeft(2, '0');
