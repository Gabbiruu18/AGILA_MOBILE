
import 'package:flutter/material.dart';
import 'attendance_service.dart';

// ---- UI helpers ----

// Cards use neutral surfaces from the theme (no blue tint).
BoxDecoration cardDeco(BuildContext context, {Color? bg}) {
  final cs = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: bg ?? cs.surface,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        blurRadius: 10,
        offset: const Offset(0, 4),
        color: cs.onSurface.withOpacity(0.06),
      ),
    ],
  );
}

String fmt(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final ap = t.period == DayPeriod.am ? "AM" : "PM";
  return "$h:$m $ap";
}
String fmtRange(TimeOfDay a, TimeOfDay b) => "${fmt(a)}–${fmt(b)}";

// Status → chip colors (kept simple & readable on both modes)
Color statusBg(SessStatus? st) {
  if (st == null) return Colors.grey.shade200;
  switch (st) {
    case SessStatus.present:
    case SessStatus.excused: return const Color(0xFFDCF5E7);
    case SessStatus.late:    return const Color(0xFFFFF1CC);
    case SessStatus.absent:  return const Color(0xFFFFE0E0);
  }
}
Color statusFg(SessStatus? st) {
  if (st == null) return Colors.grey.shade600;
  switch (st) {
    case SessStatus.present:
    case SessStatus.excused: return const Color(0xFF1E7E34);
    case SessStatus.late:    return const Color(0xFF9A6B00);
    case SessStatus.absent:  return const Color(0xFFB3261E);
  }
}

// ----- Period Switcher -----
class PeriodSwitcher extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const PeriodSwitcher({super.key, required this.label, required this.onPrev, required this.onNext});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
      Expanded(
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ),
      ),
      IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
    ]);
  }
}

// ----- Stat Card -----
class StatCard extends StatelessWidget {
  final String label; final int value; final IconData icon; final Color tint;
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.tint});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
          color:  cs.surface,
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

// ----- Section Title with lines -----
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
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.primary, fontWeight: FontWeight.w700, fontSize: 14,
          ),
        ),
      ),
      const Expanded(child: ThinLine()),
    ]);
  }
}
class ThinLine extends StatelessWidget {
  const ThinLine({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: 1.2, color: Theme.of(context).colorScheme.outlineVariant);
}

/* ===== Daily list ===== */
class DailyList extends StatelessWidget {
  final List<SubjectDayGroup> groups;
  const DailyList({super.key, required this.groups});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(context),
        child: const Text("No classes today."),
      );
    }
    return ListView.builder(
      itemCount: groups.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final g = groups[i];
        final anyLab = g.sessions.any((s) => s.kind != null);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(
            context,
            bg: anyLab ? cs.surfaceContainerHighest : cs.surface,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              g.subjectDisplay,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: g.sessions.map((s) {
                final label = fmtRange(s.start, s.end);
                return Chip(
                  label: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                  backgroundColor: cs.surface,
                  shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
                );
              }).toList(),
            ),
          ]),
        );
      },
    );
  }
}

/* ===== Weekly list (colored day chips) ===== */
class WeeklyList extends StatelessWidget {
  final List<SubjectWeekItem> items;
  const WeeklyList({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(context), child: const Text("No subjects scheduled this week."));
    }
    return ListView.builder(
      itemCount: items.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final it = items[i];
        const days = ["M", "T", "W", "Th", "F"];
        final pct = it.total == 0 ? 0.0 : it.attended / it.total;
        final isLabLike = it.subjectDisplay.endsWith("(Lab)") || it.subjectDisplay.endsWith("(ComLab)");
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(context, bg: isLabLike ? cs.surface : cs.surface),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(it.subjectDisplay, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              Text("${it.attended}/${it.total}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
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
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                final st = it.statuses[i]; // SeesStatus? for this day
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg(st),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(
                    days[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11, fontWeight: FontWeight.w700, color: statusFg(st),
                    ),
                  ),
                );
              }),
            ),
          ]),
        );
      },
    );
  }
}

/* ===== Monthly list ===== */
class MonthlyList extends StatelessWidget {
  final List<SubjectTotals> items;
  const MonthlyList({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(context), child: const Text("No monthly data yet."));
    }
    return ListView.builder(
      itemCount: items.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final it = items[i];
        final pct = it.total == 0 ? 0.0 : it.attended / it.total;
        final isLabLike = it.subjectDisplay.endsWith("(Lab)") || it.subjectDisplay.endsWith("(ComLab)");
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(context, bg: isLabLike ? cs.surface : cs.surface),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(it.subjectDisplay, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              Text("${it.attended}/${it.total}", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
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
          ]),
        );
      },
    );
  }
}

// ===== Schedule-like "Today" Card for Attendance =====

class _ChipColors {
  final Color bg;
  final Color fg;
  const _ChipColors(this.bg, this.fg);
}

// Theme-aware "Scheduled" chip
_ChipColors _chipForScheduled(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return _ChipColors(cs.primary.withOpacity(0.12), cs.primary);
}

// Deterministic color bar based on subject name (kept)
Color _subjectAccent(String subject) {
  const palette = <Color>[
    Color(0xFF6CA9FF), Color(0xFFFFC66C), Color(0xFF9BE7B1),
    Color(0xFFB39DDB), Color(0xFFFFAB91), Color(0xFF80CBC4),
    Color(0xFFA5D6A7), Color(0xFFFFCC80), Color(0xFF90CAF9), Color(0xFFF48FB1),
  ];
  var h = 0;
  for (final c in subject.codeUnits) {
    h = (h * 31 + c) & 0x7FFFFFFF;
  }
  return palette[h % palette.length];
}

class TodayScheduleLikeCard extends StatelessWidget {
  final String subject;
  final String section;
  final String room;
  final String timeLabel;
  final String statusLabel;
  final Color statusBg;
  final Color statusFg;
  final Color accentColor;
  final VoidCallback? onViewDetails;

  const TodayScheduleLikeCard({
    super.key,
    required this.subject,
    required this.section,
    required this.room,
    required this.timeLabel,
    required this.statusLabel,
    required this.statusBg,
    required this.statusFg,
    required this.accentColor,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurRadius: 10, offset: const Offset(0, 4),
              color: cs.onSurface.withOpacity(0.05),
            )
          ],
        ),
        child: Row(
          children: [
            // Left color bar
            Container(
              width: 6, height: 96,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + status chip
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: statusFg,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Meta row
                    Row(
                      children: [
                        Icon(Icons.group, size: 16, color: cs.onSurface),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            section,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.meeting_room, size: 16, color: cs.onSurface),
                        const SizedBox(width: 4),
                        Text(room),
                        const SizedBox(width: 8),
                        Icon(Icons.access_time, size: 14, color: cs.onSurface),
                        const SizedBox(width: 2),
                        Text(timeLabel, style: TextStyle(color: cs.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Details'),
                        onPressed: onViewDetails,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayItem {
  final SubjectDayGroup g;
  final dynamic s; // session object with .start and .end
  _DayItem(this.g, this.s);
}

class DailyListScheduleLike extends StatelessWidget {
  final List<SubjectDayGroup> groups;
  const DailyListScheduleLike({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    final List<_DayItem> items = [];
    for (final g in groups) {
      for (final s in g.sessions) {
        items.add(_DayItem(g, s));
      }
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(context),
        child: const Text("No classes today."),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final g = items[i].g;
        final s = items[i].s;

        // theme-aware scheduled chip
        final chip = _chipForScheduled(ctx);

        return TodayScheduleLikeCard(
          subject: g.subjectDisplay,
          section: s.section,
          room: s.room,
          timeLabel: fmtRange(s.start, s.end),
          statusLabel: 'Scheduled',
          statusBg: chip.bg,
          statusFg: chip.fg,
          accentColor: _subjectAccent(g.subjectDisplay),
          onViewDetails: () {
            showModalBottomSheet(
              context: ctx,
              showDragHandle: true,
              builder: (_) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(g.subjectDisplay, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _kv(ctx, 'Time', fmtRange(s.start, s.end)),
                    _kv(ctx, 'Section', s.section),
                    _kv(ctx, 'Room', s.room),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// small key–value row for the sheet
Widget _kv(BuildContext context, String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 90,
        child: Text(
          k,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(v)),
    ],
  ),
);
