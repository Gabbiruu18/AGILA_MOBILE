import 'package:flutter/material.dart';
// Import the shimmer package
import 'package:intl/intl.dart';
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

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'N/A';
  return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
}

BoxDecoration cardDeco(BuildContext context, {Color? bg}) {
  final cs = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: bg ?? cs.surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: cs.onSurface.withOpacity(0.06))],
  );
}

// UPDATED: Now uses the AttendanceStatus enum
Color statusBg(AttendanceStatus? st) {
  if (st == null) return Colors.grey.shade200;
  switch (st) {
    case AttendanceStatus.scheduled: return const Color(0xFFDCECFF); // Blue for scheduled
    case AttendanceStatus.present:   return const Color(0xFFDCF5E7);
    case AttendanceStatus.excused:   return const Color(0xFFE6F9FF); // Light blue for excused
    case AttendanceStatus.late:      return const Color(0xFFFFF1CC);
    case AttendanceStatus.absent:    return const Color(0xFFFFE0E0);
    case AttendanceStatus.none:    return const Color(0xFFB2B2B2);

  }
}
Color statusFg(AttendanceStatus? st) {
  if (st == null) return Colors.grey.shade600;
  switch (st) {
    case AttendanceStatus.scheduled: return const Color(0xFF0058CE);
    case AttendanceStatus.present:   return const Color(0xFF1E7E34);
    case AttendanceStatus.excused:   return const Color(0xFF0096C7); // Blue for excused
    case AttendanceStatus.late:      return const Color(0xFF9A6B00);
    case AttendanceStatus.absent:    return const Color(0xFFB3261E);
    case AttendanceStatus.none:      return  Color(0xFF545353);


  }
}


String statusText(AttendanceStatus? st, {String? source}) {
  if (st == null) return "N/A";

  // // Special case for "No attendance session created"
  // if (st == AttendanceStatus.absent && source == "No attendance session created") {
  //   return "Done";
  // }

  return st.name[0].toUpperCase() + st.name.substring(1);
}

class StatusFilterDialog extends StatelessWidget {
  final List<Session> sessions;
  final VoidCallback onClose;
  final AttendanceStatus status;

  const StatusFilterDialog({
    super.key,
    required this.sessions,
    required this.onClose,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${statusText(status)} Classes",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text("No classes with this status")),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return ListTile(
                      title: Text(session.subject),
                      subtitle: Text("${session.section} • ${fmtRange(session.startMinutes, session.endMinutes)}"),
                      leading: CircleAvatar(
                        backgroundColor: statusBg(status),
                        foregroundColor: statusFg(status),
                        child: const Icon(Icons.class_),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EnhancedPeriodSwitcher extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onLabelTap;
  final VoidCallback onTodayTap;
  // NEW: Pass the canShiftPrev boolean
  final bool showPrev;
  final bool showNext;
  final bool showTodayButton;

  const EnhancedPeriodSwitcher({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onLabelTap,
    required this.onTodayTap,
    // NEW
    required this.showPrev,
    required this.showNext,
    required this.showTodayButton,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // This layout is more robust and prevents overflows.
    return Row(
      children: [
        // Left-side widget (either the Today button or an empty box for balance)
        SizedBox(
          width: 90,
          child: showTodayButton
              ? TextButton(
            onPressed: onTodayTap,
            child: const Text('Today'),
          )
              : null,
        ),

        // The flexible center part that expands and shrinks
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                // Use the new showPrev flag to enable/disable the button
                onPressed: showPrev ? onPrev : null,
                icon: Icon(Icons.chevron_left, color: showPrev ? cs.onSurface : cs.onSurface.withOpacity(0.38)),
              ),
              // Make the label flexible to prevent overflow
              Flexible(
                child: InkWell(
                  onTap: onLabelTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis, // Prevent long text from overflowing
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
            ],
          ),
        ),

        // Right-side empty box to balance the layout
        const SizedBox(width: 90),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
        child: Row(
          children: [
            // Left side with icon and label
            Row(
              children: [
                CircleAvatar(
                    radius: 14,
                    backgroundColor: tint.withOpacity(0.15),
                    child: Icon(icon, size: 16, color: tint)
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Expanded space to push the number to the right
            const Spacer(),

            // Right side with the count number
            Text(
              "$value",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ],
        ),
      ),
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
    if (groups.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(context), child: const Center(child: Text("No classes scheduled for this day.")));
    }

    // Flatten the groups into a single list of sessions
    final items = groups.expand((g) => g.sessions).toList();
    items.sort((a,b) => a.startMinutes.compareTo(b.startMinutes));

    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final session = items[i];
        return TodayScheduleCard(
          subject: session.subject,
          roomType: session.roomType,
          section: session.section,
          room: session.room,
          timeLabel: fmtRange(session.startMinutes, session.endMinutes),

          // UPDATED: Pass the status enum directly.
          status: session.status,
          source: session.source, // Add this line

          accentColor: _subjectAccent(session.subject),
          onViewDetails: () => onViewDetails(session),
        );
      },
    );
  }
}

class WeeklyList extends StatelessWidget {
  final List<SubjectWeekItem> items;
  final void Function(SubjectWeekItem item)? onItemTap;
  final void Function(SubjectWeekItem item, String roomType, int weekday)? onStatusTap;

  const WeeklyList({
    super.key,
    required this.items,
    this.onItemTap,
    this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(context),
        child: const Center(child: Text("No subjects scheduled this week.")),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final item = items[i];
        const days = ["M", "T", "W", "Th", "F", "S"];
        final roomTypes = item.roomTypes;

        return GestureDetector(
          onTap: onItemTap != null ? () => onItemTap!(item) : null,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: cardDeco(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subjectDisplay,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),

                // Add a summary of attendance
                Text(
                  "Attendance: ${item.attended}/${item.total}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),

                // Create a row for each room type
                ...roomTypes.map((roomType) {
                  final statuses = item.getStatusesForRoomType(roomType);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        // Room type label
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            roomType,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Status indicators for each day
                        ...List.generate(6, (dayIndex) {
                          // Safely get the status, defaulting to null if out of bounds.
                          final status = (dayIndex < statuses.length) ? statuses[dayIndex] : null;
                          final weekday = dayIndex + 1;

                          return GestureDetector(
                            onTap: status != null && onStatusTap != null
                                ? () => onStatusTap!(item, roomType, weekday)
                                : null,
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBg(status),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                days[dayIndex],
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusFg(status),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MonthlyList extends StatelessWidget {
  final List<SubjectTotals> items;
  final void Function(SubjectTotals item)? onItemTap;

  const MonthlyList({
    super.key,
    required this.items,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(context),
        child: const Center(child: Text("No subjects scheduled this month.")),
      );
    }

    // Group items by subject
    final bySubject = <String, List<SubjectTotals>>{};
    for (final item in items) {
      bySubject.putIfAbsent(item.subjectDisplay, () => []).add(item);
    }

    return ListView.builder(
      itemCount: bySubject.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final subjectName = bySubject.keys.elementAt(i);
        final subjectItems = bySubject[subjectName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Text(
                subjectName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
            ...subjectItems.map((item) {
              final pct = item.total == 0 ? 0.0 : item.attended / item.total;

              return GestureDetector(
                onTap: onItemTap != null ? () => onItemTap!(item) : null,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: cardDeco(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.roomType,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${item.attended}/${item.total}",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: pct,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(cs.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

Color _subjectAccent(String subject) {
  const palette = <Color>[Color(0xFF6CA9FF), Color(0xFFFFC66C), Color(0xFF9BE7B1), Color(0xFFB39DDB), Color(0xFFFFAB91), Color(0xFF80CBC4)];
  return palette[subject.hashCode % palette.length];
}

class TodayScheduleCard extends StatelessWidget {
  // UPDATED: Simplified parameters.
  final String subject, roomType, section, room, timeLabel;
  final AttendanceStatus status;
  final Color accentColor;
  final VoidCallback? onViewDetails;
  final String? source; // Add this field


  const TodayScheduleCard({
    super.key, required this.subject, required this.section, required this.room,
    required this.timeLabel, required this.status, required this.accentColor,
    this.onViewDetails, required this.roomType, this.source
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sLabel = statusText(status, source: source); // Use the class field
    final sBg = statusBg(status);
    final sFg = statusFg(status);

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
                      // UPDATED: Display subject name and room type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(roomType, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(999)), child: Text(sLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: sFg, fontWeight: FontWeight.w600, fontSize: 12))),
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
    // Get attendance status color and label
    final sBg = statusBg(session.status);
    final sFg = statusFg(session.status);
    final sLabel = statusText(session.status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(session.section, style: Theme.of(context).textTheme.titleSmall),
        const Divider(height: 24),

        // Special message for "No attendance session created" case
        if (session.source == "No attendance session created")
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "No attendance session was created for this schedule.",
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),

        // Attendance status chip
        if (session.status != AttendanceStatus.scheduled) ...[
          Row(
            children: [
              const Text("Attendance Status:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      session.status == AttendanceStatus.present ? Icons.check_circle :
                      session.status == AttendanceStatus.late ? Icons.schedule :
                      session.status == AttendanceStatus.excused ? Icons.event_available :
                      Icons.cancel,
                      color: sFg,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sLabel,
                      style: TextStyle(color: sFg, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Attendance details
          if (session.source != null && session.source != "No attendance session created")
            _kv(context, Icons.source, 'Source', session.source!),
          if (session.firstSeen != null)
            _kv(context, Icons.login, 'First Seen', formatDateTime(session.firstSeen)),
          if (session.lastSeen != null)
            _kv(context, Icons.logout, 'Last Seen', formatDateTime(session.lastSeen)),
          if (session.updatedAt != null)
            _kv(context, Icons.update, 'Updated At', formatDateTime(session.updatedAt)),


          const Divider(height: 24),
        ],

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 42), // Added top spacing
        CircleAvatar(
          radius: 65,
          backgroundImage: details.photoURL != null ? NetworkImage(details.photoURL!) : null,
          child: details.photoURL == null ? const Icon(Icons.person, size: 60) : null,
        ),
        const SizedBox(height: 16),
        Text(
          details.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (details.departmentName != null) ...[
          const SizedBox(height: 4),
          Text(
            details.departmentName!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
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

// ============================ SKELETON WIDGETS ============================
// NEW: All of the following widgets are for the loading state.

class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  const _SkeletonBox({this.width, required this.height});
  @override
  Widget build(BuildContext context) {
    // The color is now INSIDE the BoxDecoration, which is the correct way.
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class DailyListSkeleton extends StatelessWidget {
  const DailyListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => Container(
        decoration: cardDeco(context),
        child: Row(children: [
          Container(width: 6, height: 96, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)))),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: _SkeletonBox(height: 18, width: 150)),
                    SizedBox(width: 10),
                    _SkeletonBox(height: 24, width: 70),
                  ]),
                  SizedBox(height: 8),
                  _SkeletonBox(height: 14, width: 200),
                  SizedBox(height: 12),
                  _SkeletonBox(height: 36),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class WeeklyListSkeleton extends StatelessWidget {
  const WeeklyListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) => Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: cardDeco(context),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(height: 18, width: 220),
                  SizedBox(height: 12),
                  Row(children: [
                    _SkeletonBox(height: 22, width: 30),
                    SizedBox(width: 6),
                    _SkeletonBox(height: 22, width: 30),
                    SizedBox(width: 6),
                    _SkeletonBox(height: 22, width: 30),
                    SizedBox(width: 6),
                    _SkeletonBox(height: 22, width: 30),
                    SizedBox(width: 6),
                    _SkeletonBox(height: 22, width: 30),
                  ]),
                ]
            )
        )
    );
  }
}

class MonthlyListSkeleton extends StatelessWidget {
  const MonthlyListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, i) => Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: cardDeco(context),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: _SkeletonBox(height: 18, width: 220)),
                    SizedBox(width: 10),
                    _SkeletonBox(height: 16, width: 40),
                  ]),
                  SizedBox(height: 12),
                  _SkeletonBox(height: 8),
                ]
            )
        )
    );
  }
}