import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project_agila/Service_Modules/Attendance/attendance_controller.dart';
import 'package:project_agila/Service_Modules/Attendance/attendance_UI.dart';
import 'package:project_agila/Service_Modules/Attendance/attendance_service.dart';

const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AGILA Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kAgilaBlue),
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: Color(0xFFFFFFFF),
      ),
      home: const AttendanceScreen(),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final AttendanceController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = AttendanceController(
      service: InMemoryAttendanceService(),
      userId: 'demo-user',
    )
      ..addListener(() => setState(() {}))
      ..refresh();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ctrl.state.counts;

    return Scaffold(
      //backgroundColor: kBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        elevation: 0,
        //backgroundColor: kBg,
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
                Text(
                  ctrl.state.mode.name.substring(0,1).toUpperCase() + ctrl.state.mode.name.substring(1),
                ),
                Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
              ]),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PeriodSwitcher(

                label: ctrl.periodLabel(),
                onPrev: () => ctrl.shiftPeriod(-1),
                onNext: () => ctrl.shiftPeriod(1),
              ),
              if (ctrl.state.loading) const LinearProgressIndicator(minHeight: 2),
              if (ctrl.state.error != null)
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB3261E).withOpacity(.25)),
                  ),
                  child: Text(ctrl.state.error!, style: const TextStyle(color: Color(0xFFB3261E))),
                ),

              const SizedBox(height: 8),
              const LinedTitle("Report"),
              const SizedBox(height: 12),

              Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatCard(label: "Present", value: c.present, icon: Icons.check_circle, tint: const Color(0xFF22A06B)),
                  StatCard(label: "Lates",   value: c.lates,   icon: Icons.schedule,    tint: const Color(0xFFCC8A00)),
                  StatCard(label: "Absents", value: c.absents, icon: Icons.cancel,      tint: const Color(0xFFD22D2D)),
                ],
              ),
              const SizedBox(height: 24),
              if (ctrl.state.mode == ViewMode.daily) ...[
                const LinedTitle("Today’s Subjects"),
                const SizedBox(height: 12),
                DailyListScheduleLike(groups: ctrl.state.dailyGroups),
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
    );
  }
}
