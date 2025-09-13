import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'attendance_service.dart';

// THEME
const kAgilaBlue = Color(0xFF0058CE);
const kBg = Color(0xFFF6F7FB);

// ---- UI helpers ----
BoxDecoration cardDeco({Color bg = Colors.white}) => BoxDecoration(
  color: bg,
  borderRadius: BorderRadius.circular(12),
  boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.06))],
);

String fmt(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final ap = t.period == DayPeriod.am ? "AM" : "PM";
  return "$h:$m $ap";
}
String fmtRange(TimeOfDay a, TimeOfDay b) => "${fmt(a)}–${fmt(b)}";

// Status → chip colors
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
    return Row(children: [
      IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
      Expanded(child: Center(child: Text(label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700, color: kAgilaBlue,
          )))),
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
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.06))],
        border: Border.all(color: tint.withOpacity(0.2)),
      ),
      child: Column(children: [
        CircleAvatar(radius: 16, backgroundColor: tint.withOpacity(0.15), child: Icon(icon, size: 18, color: tint)),
        const SizedBox(height: 8),
        Text("$value", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
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
    return Row(children: [
      const Expanded(child: ThinLine()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(text, style: GoogleFonts.poppins(color: kAgilaBlue, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      const Expanded(child: ThinLine()),
    ]);
  }
}
class ThinLine extends StatelessWidget {
  const ThinLine({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1.2, color: Colors.grey.shade400);
}

/* ===== Daily list ===== */
class DailyList extends StatelessWidget {
  final List<SubjectDayGroup> groups;
  const DailyList({super.key, required this.groups});
  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(), child: const Text("No classes today."));
    }
    return ListView.builder(
      itemCount: groups.length, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        final g = groups[i];
        final anyLab = g.sessions.any((s) => s.kind != null);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: cardDeco(bg: anyLab ? const Color(0xFFF7FAFF) : Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.subjectDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: g.sessions.map((s) {
                final label = fmtRange(s.start, s.end);
                return Chip(
                  label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                  ),
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
    if (items.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(), child: const Text("No subjects scheduled this week."));
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
          decoration: cardDeco(bg: isLabLike ? const Color(0xFFF7FAFF) : Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(it.subjectDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Text("${it.attended}/${it.total}", style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(minHeight: 8, value: pct, backgroundColor: Colors.grey.shade300),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                final st = it.statuses[i]; // SessStatus? for this day
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg(st),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    days[i],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusFg(st)),
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
    if (items.isEmpty) {
      return Container(padding: const EdgeInsets.all(16), decoration: cardDeco(), child: const Text("No monthly data yet."));
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
          decoration: cardDeco(bg: isLabLike ? const Color(0xFFF7FAFF) : Colors.white),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(it.subjectDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Text("${it.attended}/${it.total}", style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(minHeight: 8, value: pct, backgroundColor: Colors.grey.shade300),
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

// Use your existing status colors if/when you pass real attendance statuses.
// For now we’ll default to a neutral "Scheduled" chip (blue-on-light).
_ChipColors _chipForScheduled() => const _ChipColors(Color(0xFFE9F1FF), kAgilaBlue);

// Deterministic color bar based on subject name (so same subject = same color)
Color _subjectAccent(String subject) {
  // simple hash → pick from palette
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
  final String subject;       // e.g., group.subjectDisplay
  final String section;       // if unknown, pass '—'
  final String room;          // if unknown, pass '—'
  final String timeLabel;     // fmtRange(start, end)
  final String statusLabel;   // "Scheduled" by default
  final Color statusBg;
  final Color statusFg;
  final Color accentColor;    // left color barF
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            blurRadius: 10, offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.05),
          )],
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
                            style: const TextStyle(
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
                            style: TextStyle(
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
                        const Icon(Icons.group, size: 16, color: Colors.black45),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            section,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.meeting_room, size: 16, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(room),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time, size: 14, color: Colors.black38),
                        const SizedBox(width: 2),
                        Text(timeLabel, style: const TextStyle(color: Colors.black54)),
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
  final List<SubjectDayGroup> groups; // same type you already use in DailyList
  const DailyListScheduleLike({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    // Flatten sessions with their group for rendering
    final List<_DayItem> items = [];
    for (final g in groups) {
      for (final s in g.sessions) {
        items.add(_DayItem(g, s));
      }
    }

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDeco(),
        child: const Text("No classes today."),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final g = items[i].g;
        final s = items[i].s;

        // schedule-style chip (blue "Scheduled")
        final chip = _chipForScheduled();

        return TodayScheduleLikeCard(
          subject: g.subjectDisplay,
          section: s.section,
          room: s.room,
          timeLabel: fmtRange(s.start, s.end), // uses your existing fmtRange(TimeOfDay, TimeOfDay)
          statusLabel: 'Scheduled',
          statusBg: chip.bg,
          statusFg: chip.fg,
          accentColor: _subjectAccent(g.subjectDisplay),
          onViewDetails: () {
            showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (_) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(g.subjectDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _kv('Time', fmtRange(s.start, s.end)),
                    _kv('Section', s.section),
                    _kv('Room', s.room),

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
Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 90, child: Text(k, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600))),
    const SizedBox(width: 8),
    Expanded(child: Text(v)),
  ]),
);

