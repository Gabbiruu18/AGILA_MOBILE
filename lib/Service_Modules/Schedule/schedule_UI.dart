import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'schedule_service.dart';

// ============================ HELPERS ============================

class ChipColors {
  final Color bg;
  final Color fg;
  const ChipColors(this.bg, this.fg);
}

ChipColors statusColors(String status) {
  switch (status) {
    case 'Live':
      return const ChipColors(Color(0xFFFFF3E0), Color(0xFFE65100)); // Amber
    case 'Upcoming':
      return const ChipColors(Color(0xFFE3F2FD), Color(0xFF0D47A1)); // Blue
    default: // Done
      return const ChipColors(Color(0xFFE8F5E9), Color(0xFF1B5E20)); // Green
  }
}

String weekdayLabel(int d) {
  if (d < 1 || d > 7) return '';
  return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
}

Map<int, DateTime> weekDatesMonToSun(DateTime base) {
  final mon = base.subtract(Duration(days: base.weekday - 1));
  return {for (var i = 0; i < 7; i++) i + 1: mon.add(Duration(days: i))};
}

String d2(int n) => n.toString().padLeft(2, '0');


// ============================ UI WIDGETS ============================

class SessionCard extends StatelessWidget {
  final Session session;
  final String status;
  final VoidCallback onViewDetails;

  const SessionCard({
    super.key,
    required this.session,
    required this.status,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        '${d2(session.startMinutes ~/ 60)}:${d2(session.startMinutes % 60)}'
        ' – '
        '${d2(session.endMinutes ~/ 60)}:${d2(session.endMinutes % 60)}';
    final chipStyle = statusColors(status);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.subject,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: chipStyle.bg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(
                      color: chipStyle.fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.info_outline),
                label: const Text('View Details'),
                onPressed: onViewDetails,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MiniSessionTile extends StatelessWidget {
  final Session session;
  final bool isToday;
  final VoidCallback onTap;

  const MiniSessionTile({
    super.key,
    required this.session,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time =
        '${d2(session.startMinutes ~/ 60)}:${d2(session.startMinutes % 60)}'
        '–'
        '${d2(session.endMinutes ~/ 60)}:${d2(session.endMinutes % 60)}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(session.colorHex),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.section,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.meeting_room_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          session.room,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        if (isToday) ...[
                          const Spacer(),
                          const NowDot(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  const EmptyState({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_outlined, size: 64, color: Theme.of(context).colorScheme.surfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(message, style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class PeriodSwitcher extends StatelessWidget {
  final String label;
  final VoidCallback? onPrev, onNext;
  final bool showPrev, showNext;

  const PeriodSwitcher({super.key, required this.label, this.onPrev, this.onNext, this.showPrev = true, this.showNext = true});

  @override
  Widget build(BuildContext context) {
    Widget arrow({required bool visible, required IconData icon, required VoidCallback? onTap}) {
      return IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: visible ? Theme.of(context).colorScheme.primary : Colors.transparent),
        disabledColor: Colors.transparent,
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        arrow(visible: showPrev, icon: Icons.chevron_left, onTap: onPrev),
        Text(label, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
        arrow(visible: showNext, icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}

class NowDot extends StatelessWidget {
  const NowDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: Colors.red,
      shape: BoxShape.circle,
    ),
  );
}

// **FIXED**: Renamed to InfoChip (removed the leading underscore) to make it public.
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const InfoChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================ PANEL UI WIDGETS ============================

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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class LoadingContent extends StatelessWidget {
  const LoadingContent({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Fetching details...'),
        ],
      ),
    ),
  );
}

class ErrorContent extends StatelessWidget {
  final String error;
  const ErrorContent({super.key, required this.error});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 16),
          Text('Failed to load details.\n$error', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class SectionRosterContent extends StatelessWidget {
  final List<SectionStudent> students;
  const SectionRosterContent({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No students found for this section.'),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: student.photoURL != null ? NetworkImage(student.photoURL!) : null,
            onBackgroundImageError: student.photoURL != null ? (_, __) {} : null,
            backgroundColor: Colors.grey.shade200,
            child: student.photoURL == null ? Icon(Icons.person_outline, color: Colors.grey.shade600) : null,
          ),
          title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        );
      },
    );
  }
}

class RoomScheduleContent extends StatelessWidget {
  final List<RoomSchedule> schedules;
  const RoomScheduleContent({super.key, required this.schedules});

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No classes scheduled in this room today.'),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final s = schedules[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${s.sectionName}\n${s.professor}'),
            trailing: Text(s.time, style: const TextStyle(fontSize: 12)),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}