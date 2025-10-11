import 'package:flutter/material.dart';
import 'attendance_service.dart';
import 'attendance_controller.dart';

// ============================ HELPERS (Copied for Independence) ============================

String _d2(int n) => n.toString().padLeft(2, '0');
String fmtTime(int minutes) {
  if (minutes < 0) return "N/A";
  final tod = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
  final m = _d2(tod.minute);
  final ap = tod.period == DayPeriod.am ? "AM" : "PM";
  return "$h:$m $ap";
}
String fmtRange(int startMinutes, int endMinutes) => "${fmtTime(startMinutes)}–${fmtTime(endMinutes)}";


BoxDecoration cardDeco(BuildContext context, {Color? bg}) {
  final cs = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: bg ?? cs.surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: cs.onSurface.withOpacity(0.06))],
  );
}

Color statusBg(SessStatus? st) {
  if (st == null) return Colors.grey.shade200;
  switch (st) {
    case SessStatus.scheduled: return const Color(0xFFDCECFF); // Blue for scheduled
    case SessStatus.present:
    case SessStatus.excused: return const Color(0xFFDCF5E7);
    case SessStatus.late:    return const Color(0xFFFFF1CC);
    case SessStatus.absent:  return const Color(0xFFFFE0E0);
  }
}
Color statusFg(SessStatus? st) {
  if (st == null) return Colors.grey.shade600;
  switch (st) {
    case SessStatus.scheduled: return const Color(0xFF0058CE);
    case SessStatus.present:
    case SessStatus.excused: return const Color(0xFF1E7E34);
    case SessStatus.late:    return const Color(0xFF9A6B00);
    case SessStatus.absent:  return const Color(0xFFB3261E);
  }
}

// ============================ UI WIDGETS ============================

class EnhancedPeriodSwitcher extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLabelTap;
  final VoidCallback onTodayTap;
  final bool showNext;
  final bool showTodayButton;

  const EnhancedPeriodSwitcher({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onLabelTap,
    required this.onTodayTap,
    required this.showNext,
    required this.showTodayButton,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (showTodayButton) ...[
          TextButton.icon(
            icon: const Icon(Icons.today, size: 20),
            label: const Text('Today'),
            onPressed: onTodayTap,
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const Spacer(),
        ] else
          const SizedBox(width: 48), // Balance the row

        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: InkWell(
            onTap: onLabelTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: showNext ? onNext : null,
          icon: Icon(Icons.chevron_right, color: showNext ? cs.onSurface : cs.onSurface.withOpacity(0.38)),
        ),

        if (showTodayButton) const Spacer(),
        const SizedBox(width: 48), // Balance the row
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.tint});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: cs.onSurface.withOpacity(0.06),
          ),
        ],
        border: Border.all(color: tint.withOpacity(0.2)),
      ),
      child: Column(children: [
        CircleAvatar(radius: 16, backgroundColor: tint.withOpacity(0.15), child: Icon(icon, size: 18, color: tint)),
        const SizedBox(height: 8),
        Text(
          "$value",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }
}


class LinedTitle extends StatelessWidget {
  final String text;
  const LinedTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      const Expanded(child: ThinLine()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      const Expanded(child: ThinLine()),
    ]);
  }
}
class ThinLine extends StatelessWidget {
  const ThinLine({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1.2, color: Theme.of(context).colorScheme.outlineVariant);
}

class DailyListScheduleLike extends StatelessWidget {
  final List<SubjectDayGroup> groups;
  final void Function(Session session) onViewDetails;

  const DailyListScheduleLike({super.key, required this.groups, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final items = groups.expand((g) => g.sessions).toList();

    if (items.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(context), child: const Center(child: Text("No classes scheduled for this day.")));
    }

    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final session = items[i];
        return TodayScheduleCard(
          subject: session.subject,
          section: session.section,
          room: session.room,
          timeLabel: fmtRange(session.startMinutes, session.endMinutes),
          statusLabel: 'Scheduled',
          statusBg: statusBg(SessStatus.scheduled),
          statusFg: statusFg(SessStatus.scheduled),
          accentColor: _subjectAccent(session.subject),
          onViewDetails: () => onViewDetails(session),
        );
      },
    );
  }
}

class WeeklyList extends StatelessWidget {
  final List<SubjectWeekItem> items;
  const WeeklyList({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(context), child: const Center(child: Text("No subjects scheduled this week.")));
    }
    return ListView.builder(
        itemCount: items.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) {
          final it = items[i];
          const days = ["M", "T", "W", "Th", "F"];
          return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: cardDeco(context),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.subjectDisplay, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (i) {
                    final st = it.statuses[i];
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusBg(st), borderRadius: BorderRadius.circular(999)),
                      child: Text(days[i], style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: statusFg(st))),
                    );
                  }),
                ),
              ]));
        });
  }
}

class MonthlyList extends StatelessWidget {
  final List<SubjectTotals> items;
  const MonthlyList({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(context), child: const Center(child: Text("No subjects scheduled this month.")));
    }
    return ListView.builder(
        itemCount: items.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) {
          final it = items[i];
          final pct = it.total == 0 ? 0.0 : it.attended / it.total;
          return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: cardDeco(context),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(it.subjectDisplay, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  Text("${it.attended}/${it.total}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(minHeight: 8, value: pct, backgroundColor: cs.surfaceContainerHighest, valueColor: AlwaysStoppedAnimation(cs.primary))),
              ]));
        });
  }
}

Color _subjectAccent(String subject) {
  const palette = <Color>[Color(0xFF6CA9FF), Color(0xFFFFC66C), Color(0xFF9BE7B1), Color(0xFFB39DDB), Color(0xFFFFAB91), Color(0xFF80CBC4)];
  return palette[subject.hashCode % palette.length];
}

class TodayScheduleCard extends StatelessWidget {
  final String subject, section, room, timeLabel, statusLabel;
  final Color statusBg, statusFg, accentColor;
  final VoidCallback? onViewDetails;

  const TodayScheduleCard({
    super.key, required this.subject, required this.section, required this.room,
    required this.timeLabel, required this.statusLabel, required this.statusBg,
    required this.statusFg, required this.accentColor, this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant.withOpacity(0.5)), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(width: 6, height: 96, decoration: BoxDecoration(color: accentColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)), child: Text(statusLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusFg, fontWeight: FontWeight.w600, fontSize: 12))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.meeting_room, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(room),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(timeLabel, style: TextStyle(color: cs.onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.visibility_outlined), label: const Text('View Details'), onPressed: onViewDetails)),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================ PANEL UI WIDGETS (Standard Version) ============================

class SessionDetailsPanel extends StatelessWidget {
  final Session session;
  final Future<List<SectionStudent>> Function() fetchStudents;
  final Future<InstructorDetails?> Function() fetchInstructor;

  const SessionDetailsPanel({super.key, required this.session, required this.fetchStudents, required this.fetchInstructor});

  @override
  Widget build(BuildContext context) {
    return SlidingPanel(
        title: session.subject,
        child: _SessionDetailsContent(
          session: session,
          fetchStudents: fetchStudents,
          fetchInstructor: fetchInstructor,
        )
    );
  }
}


class _SessionDetailsContent extends StatelessWidget {
  final Session session;
  final Future<List<SectionStudent>> Function() fetchStudents;
  final Future<InstructorDetails?> Function() fetchInstructor;

  const _SessionDetailsContent({required this.session, required this.fetchStudents, required this.fetchInstructor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(session.section, style: Theme.of(context).textTheme.titleSmall),
        const Divider(height: 24),
        _kv(context, Icons.schedule, 'Time', fmtRange(session.startMinutes, session.endMinutes)),
        _kv(context, Icons.meeting_room_outlined, 'Room', session.room),
        if (session.instructorName != null) _kv(context, Icons.person_outline, 'Instructor', session.instructorName!),
        const Divider(height: 24),
        DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TabBar(tabs: [Tab(text: "Instructor"), Tab(text: "Classmates")]),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: TabBarView(children: [
                  FutureBuilder<InstructorDetails?>(
                    future: fetchInstructor(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const LoadingContent();
                      if (snapshot.hasError || snapshot.data == null) return const ErrorContent(error: "Instructor details not found.");
                      return _InstructorDetailsContent(details: snapshot.data!);
                    },
                  ),
                  FutureBuilder<List<SectionStudent>>(
                    future: fetchStudents(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const LoadingContent();
                      if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) return const ErrorContent(error: "No classmates found.");
                      return _SectionRosterContent(students: snapshot.data!);
                    },
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SlidingPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const SlidingPanel({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingContent extends StatelessWidget {
  const LoadingContent({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Fetching details...')])));
}

class ErrorContent extends StatelessWidget {
  final String error;
  const ErrorContent({super.key, required this.error});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, color: Colors.red, size: 40), const SizedBox(height: 16), Text('Failed to load details.\n$error', textAlign: TextAlign.center)])));
}

class _InstructorDetailsContent extends StatelessWidget {
  final InstructorDetails details;
  const _InstructorDetailsContent({required this.details});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CircleAvatar(radius: 40, backgroundImage: details.photoURL != null ? NetworkImage(details.photoURL!) : null, child: details.photoURL == null ? const Icon(Icons.person, size: 40) : null),
      const SizedBox(height: 16),
      Text(details.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      if (details.departmentName != null) ...[
        const SizedBox(height: 4),
        Text(details.departmentName!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ]);
  }
}

class _SectionRosterContent extends StatelessWidget {
  final List<SectionStudent> students;
  const _SectionRosterContent({required this.students});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return ListTile(
          leading: CircleAvatar(backgroundImage: student.photoURL != null ? NetworkImage(student.photoURL!) : null, child: student.photoURL == null ? const Icon(Icons.person) : null),
          title: Text(student.name),
        );
      },
    );
  }
}

Widget _kv(BuildContext context, IconData icon, String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(children: [
    Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
    const SizedBox(width: 12),
    SizedBox(width: 80, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
    Expanded(child: Text(v)),
  ]),
);