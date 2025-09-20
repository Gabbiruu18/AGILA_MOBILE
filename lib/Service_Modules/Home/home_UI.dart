import 'package:flutter/material.dart';
const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

class AppCard extends StatelessWidget {
  final Widget? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      if (title != null) ...[
        DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
          child: title!,
        ),
        const SizedBox(height: 12),
      ],
      child,
    ];

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.surface),
        boxShadow: const [
          BoxShadow(blurRadius: 10, offset: Offset(0, 6), color: Color(0x1A000000)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: content),
    );
  }
}

class HeaderBar extends StatelessWidget {
  final String greeting;
  final String name;
  final String role;
  final String? courseName;       // used for students
  final String? sectionName;      // used for students
  final String? departmentName;// ✅ NEW: used for teachers/heads
  final VoidCallback onOpenNotifications;
  final int unreadCount;

  const HeaderBar({
    super.key,
    required this.greeting,
    required this.name,
    required this.role,
    required this.courseName,
    required this.sectionName,
    required this.onOpenNotifications,
    required this.unreadCount,
    required this.departmentName,
    // ✅ NEW (optional)
  });

  bool get _isTeacherOrHead =>
      role == 'teacher' || role == 'program_head' || role == 'academic_head';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting + name + notif
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 14,
                      )),
                  Text(name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      )),
                ],
              ),
              GestureDetector(
                onTap: onOpenNotifications,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_none,
                        color: Theme.of(context).colorScheme.primary, size: 30),
                    if (unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: cs.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tags row (scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Always show role
                TagChip(
                  label: role,
                  color: Theme.of(context).colorScheme.primary,
                  icon: _isTeacherOrHead ? Icons.school : Icons.person,
                ),

                // If teacher/head: show Department
                if (_isTeacherOrHead && departmentName != null && departmentName!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TagChip(
                    label: departmentName!,
                    color: Theme.of(context).colorScheme.secondary,
                    icon: Icons.domain, // or Icons.apartment
                  ),
                ],

                // If student: show Course + Section
                if (!_isTeacherOrHead && courseName != null && courseName!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TagChip(
                    label: courseName!,
                    color: Theme.of(context).colorScheme.secondary,
                    icon: Icons.menu_book,
                  ),
                ],
                if (!_isTeacherOrHead && sectionName != null && sectionName!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TagChip(
                    label: sectionName!,
                    color: const Color(0xFF33B864),
                    icon: Icons.group,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const TagChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.onPrimary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class NotesPreviewCard extends StatelessWidget {
  final String noteText;
  final VoidCallback onEdit;

  const NotesPreviewCard({super.key, required this.noteText, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final truncated = _truncate(noteText, 120); // ~2 lines typical

    return AppCard(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text('Your Notes'),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
            tooltip: 'Edit notes',
          ),
        ],
      ),
      child: Text(
        truncated.isEmpty ? 'Tap the pencil to add a note' : truncated,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, color: const Color(0xFF0F172A)),
      ),
    );
  }

  String _truncate(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}

class NotesDialog extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onReset;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const NotesDialog({
    super.key,
    required this.controller,
    required this.onReset,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Your Notes"),
      content: TextField(
        controller: controller,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Type your notes here...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onReset,
          child: Text("Reset", style: TextStyle(color: Colors.red)),
        ),
        TextButton(
          onPressed: onCancel,
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: onSave,
          child: Text("Save"),
        ),
      ],
    );
  }
}


class ScheduleItem {
  final String subjectName;
  final String professor; // can be empty for teacher view
  final String startTime;
  final String endTime;
  final String? courseName;
  final String? sectionName;
  final String? room;

  ScheduleItem({
    required this.subjectName,
    required this.professor,
    required this.startTime,
    required this.endTime,
    this.courseName,
    this.sectionName,
    this.room,
  });
}

class TeacherScheduleCard extends StatelessWidget {
  final List<ScheduleItem> items;
  final String title; // e.g., "Schedule for Today"

  const TeacherScheduleCard({
    super.key,
    required this.items,
    this.title = 'Schedule for Today',
  });

  @override
  Widget build(BuildContext context) {
    return _SideBorderCard(
      sideColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),

          // Show placeholder if no schedules
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text(
                  'No schedules for today',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, color: Colors.grey),
                ),
              ),
            )
          else
          // Row-style chips + details
            ...List.generate(items.length, (i) {
              final it = items[i];
              return Container(
                margin: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject row + time on trailing side
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            it.subjectName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              '${it.startTime} — ${it.endTime}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Chips: Section, Course, Room
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (it.sectionName != null && it.sectionName!.trim().isNotEmpty)
                          _InfoChip(icon: Icons.group, label: it.sectionName!),
                        if (it.courseName != null && it.courseName!.trim().isNotEmpty)
                          _InfoChip(icon: Icons.menu_book, label: it.courseName!),
                        if (it.room != null && it.room!.trim().isNotEmpty)
                          _InfoChip(icon: Icons.meeting_room, label: 'Room ${it.room!}'),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class StudentScheduleCard extends StatelessWidget {
  final List<ScheduleItem> items;
  final String title;

  const StudentScheduleCard({
    super.key,
    required this.items,
    this.title = 'Schedule for Today',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _SideBorderCard(
      sideColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),

          // Show placeholder if no schedules
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text(
                  'No schedules for today',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, color: Colors.grey),
                ),
              ),
            )
          else
            ...List.generate(items.length, (i) {
              final it = items[i];
              return Container(
                margin: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            it.subjectName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              '${it.startTime} — ${it.endTime}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Chips: Professor, Room, Section (only)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (it.professor.trim().isNotEmpty)
                          _InfoChip(icon: Icons.person, label: it.professor),
                        if (it.room != null && it.room!.trim().isNotEmpty)
                          _InfoChip(icon: Icons.meeting_room, label: 'Room ${it.room!}'),
                        if (it.sectionName != null && it.sectionName!.trim().isNotEmpty)
                          _InfoChip(icon: Icons.group, label: it.sectionName!),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}


class TopBoxes extends StatelessWidget {
  final String monthYear;
  final String day;
  final String dayNumber;
  final VoidCallback onEditNotes;
  final String noteText;

  const TopBoxes({
    super.key,
    required this.monthYear,
    required this.day,
    required this.dayNumber,
    required this.onEditNotes,
    required this.noteText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(

      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          // Date card
          Expanded(
            child: _SideBorderCard(
              height: 140, // equal height
              sideColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(monthYear, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary,fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(dayNumber,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary,fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(day, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary,)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SideBorderCard(
              height: 140,
              sideColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: const VisualDensity(
                          horizontal: -4, vertical: -4,
                        ),
                        onPressed: onEditNotes,
                        icon: Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.primary),
                        tooltip: 'Edit notes',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      (noteText.trim().isEmpty || noteText == 'Tap to write notes')
                          ? 'Tap the pencil to add a note'
                          : noteText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideBorderCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final Color sideColor;

  const _SideBorderCard({
    required this.child,
    this.height,
    required this.sideColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // for shadow
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sideColor, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }
}