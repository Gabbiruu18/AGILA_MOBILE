import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'schedule_service.dart';

const kAgilaBlue = Color(0xFF0058CE);
const kBg = Color(0xFFF6F7FB);

BoxDecoration cardDeco({Color bg = Colors.white}) => BoxDecoration(
  color: bg,
  borderRadius: BorderRadius.circular(12),
  boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.06))],
);
// schedule_UI.dart (drop-in replacement)

class PeriodSwitcher extends StatelessWidget {
  final String label;
  final VoidCallback? onPrev; // optional
  final VoidCallback? onNext; // optional
  final bool showPrev;        // new
  final bool showNext;        // new

  const PeriodSwitcher({
    super.key,
    required this.label,
    this.onPrev,
    this.onNext,
    this.showPrev = true,
    this.showNext = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget _arrow({required bool visible, required IconData icon, required VoidCallback? onTap}) {
      // Keep the label perfectly centered even when hidden
      if (!visible) return const SizedBox(width: 48, height: 48);
      return IconButton(onPressed: onTap, icon: Icon(icon));
    }

    return Row(
      children: [
        _arrow(visible: showPrev, icon: Icons.chevron_left,  onTap: onPrev),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: kAgilaBlue,
              ),
            ),
          ),
        ),
        _arrow(visible: showNext, icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}




class SessionCard extends StatelessWidget {
  final Session session;
  final String status; // Live | Upcoming | Done
  final VoidCallback onViewDetails;
  const SessionCard({super.key, required this.session, required this.status, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final time =
        '${_d2(session.startMinutes ~/ 60)}:${_d2(session.startMinutes % 60)}'
        '–${_d2(session.endMinutes ~/ 60)}:${_d2(session.endMinutes % 60)}';

    final chip = _statusColors(status);

    return Material(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.05))],
        ),
        child: Row(
          children: [
            Container(
              width: 6, height: 96,
              decoration: BoxDecoration(
                color: Color(session.colorHex),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(session.subject, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: chip.bg, borderRadius: BorderRadius.circular(999)),
                        child: Text(status, style: GoogleFonts.poppins(color: chip.fg, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.group, size: 16),
                      const SizedBox(width: 4),
                      Expanded(child: Text(session.section, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins())),
                      const SizedBox(width: 8),
                      const Icon(Icons.meeting_room, size: 16),
                      const SizedBox(width: 4),
                      Text(session.room, style: GoogleFonts.poppins()),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time, size: 14),
                      const SizedBox(width: 2),
                      Text(time, style: GoogleFonts.poppins()),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text('Details', style: GoogleFonts.poppins()),
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

class MiniSessionTile extends StatelessWidget {
  final Session session;
  final bool isToday;
  final VoidCallback onTap;
  const MiniSessionTile({super.key, required this.session, required this.isToday, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final time =
        '${_d2(session.startMinutes ~/ 60)}:${_d2(session.startMinutes % 60)}'
        '–${_d2(session.endMinutes ~/ 60)}:${_d2(session.endMinutes % 60)}';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(blurRadius: 10, offset: const Offset(0, 4), color: Colors.black.withOpacity(0.05))],),
          child: Row(
            children: [
              Container(width: 6, height: 56, color: Color(session.colorHex)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(session.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(child: Text(session.section, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.surface))),
                    const SizedBox(width: 6),
                    Text(time, style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.surface)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.meeting_room, size: 14),
                    const SizedBox(width: 4),
                    Text(session.room, style: GoogleFonts.poppins()),
                    if (isToday) ...[const SizedBox(width: 8), const NowDot()],
                  ]),
                ]),
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
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.calendar_today, size: 64),
        const SizedBox(height: 12),
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(message, style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.surface)),
      ]),
    );
  }
}

class NowDot extends StatelessWidget {
  const NowDot({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle));
  }
}

String weekdayLabel(int d) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d - 1];
String _d2(int n) => n.toString().padLeft(2, '0');
Map<int, DateTime> weekDatesMonToSun(DateTime base) {
  final mon = base.subtract(Duration(days: base.weekday - 1));
  return {for (var i = 0; i < 7; i++) i + 1: mon.add(Duration(days: i))};
}
class ChipColors { final Color bg; final Color fg; const ChipColors(this.bg, this.fg); }
ChipColors _statusColors(String status) {
  switch (status) {
    case 'Live':     return const ChipColors(Color(0xFFFFF3E0), Color(0xFFE65100));
    case 'Upcoming': return const ChipColors(Color(0xFFE9F1FF), kAgilaBlue);
    default:         return const ChipColors(Color(0xFFE6F6EA), Color(0xFF1F8E3A)); // Done
  }
}
