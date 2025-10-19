import 'package:flutter/material.dart';
import 'dart:async'; // Added for the Marquee widget timer
const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

// ============================ HELPERS ============================

String combineName(Map<String, dynamic>? data, {String fallback = 'User'}) {
  if (data == null) return fallback;

  final firstName = data['firstName']?.toString().trim() ?? '';
  final lastName = data['lastName']?.toString().trim() ?? '';

  final combined = [firstName, lastName].where((n) => n.isNotEmpty).join(' ');
  if (combined.isNotEmpty) {
    return combined;
  }

  final singleName = data['name']?.toString().trim() ?? '';
  if (singleName.isNotEmpty) {
    return singleName;
  }

  return fallback;
}


// ============================ DATA MODELS ============================

class ScheduleItem {
  final String subjectName;
  final String professor;
  final String startTime;
  final String endTime;
  final String? courseName;
  final String? sectionName;
  final String? room;
  final String? instructorId;

  ScheduleItem({
    required this.subjectName,
    required this.professor,
    required this.startTime,
    required this.endTime,
    this.courseName,
    this.sectionName,
    this.room,
    this.instructorId,
  });
}

class InstructorDetails {
  final String firstName;
  final String lastName;
  final String name;

  final String? departmentName;
  final String? photoURL;

  String get fullName => '$firstName $lastName';

  InstructorDetails({
    required this.firstName,
    required this.lastName,
    this.departmentName,
    this.photoURL,
    required this.name,
  });
}

class SectionStudent {
  final String? firstName;
  final String? lastName;
  String get fullName => (lastName ?? '').isNotEmpty ? '$lastName, $firstName' : (firstName ?? '');
  final String name;
  final String? photoURL;

  SectionStudent({
    this.firstName,
    this.lastName,
    required this.name,
    this.photoURL,
  });
}

/*
// ===================== ANNOUNCEMENT MODEL =====================

class AnnouncementItem {
  final String title;
  final String content;
  final String? imageUrl;
  final String? authorName;
  final DateTime? createdAt;

  AnnouncementItem({
    required this.title,
    required this.content,
    this.imageUrl,
    this.authorName,
    this.createdAt,
  });
}
*/


// ============================ UI WIDGETS ============================

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

/*
// ===================== ANNOUNCEMENTS WIDGET =====================

class AnnouncementsCard extends StatelessWidget {
  final List<AnnouncementItem> announcements;
  final String title;

  const AnnouncementsCard({
    super.key,
    required this.announcements,
    this.title = 'Announcements',
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
          if (announcements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Text(
                  'No recent announcements',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, color: Colors.grey),
                ),
              ),
            )
          else
            // A horizontally scrollable list of announcements
            SizedBox(
              height: 250, // Give the list a fixed height
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final item = announcements[index];
                  return _AnnouncementItemCard(item: item);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AnnouncementItemCard extends StatelessWidget {
  final AnnouncementItem item;

  const _AnnouncementItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    String formattedDate = '';
    if (item.createdAt != null) {
      formattedDate = DateFormat('MMM d, yyyy').format(item.createdAt!);
    }

    return Container(
      width: 280, // Fixed width for each card in the horizontal list
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias, // Ensures the image respects the card's border radius
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Image Section ---
            if (item.imageUrl != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  // Loading and error builders for better UX
                  loadingBuilder: (context, child, progress) {
                    return progress == null ? child : const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40));
                  },
                ),
              )
            else
              // Placeholder if no image
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.grey[200],
                  child: Center(child: Icon(Icons.campaign, color: Colors.grey[400], size: 50)),
                ),
              ),

            // --- Content Section ---
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.content,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.authorName ?? 'Admin',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                      ),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/

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

  String _formatRole(String role) {
    if (role.isEmpty) return '';
    return role
        .split('_')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                TagChip(
                  label: _formatRole(role),
                  color: Theme.of(context).colorScheme.primary,
                  icon: _isTeacherOrHead ? Icons.school : Icons.person,
                ),

                if (_isTeacherOrHead && departmentName != null && departmentName!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TagChip(
                    label: departmentName!,
                    color: Theme.of(context).colorScheme.secondary,
                    icon: Icons.domain,
                  ),
                ],

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
    final truncated = _truncate(noteText, 120);

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

class TeacherScheduleCard extends StatelessWidget {
  final List<ScheduleItem> items;
  final String title;
  final void Function(ScheduleItem)? onItemTap;
  final void Function(String)? onSectionTap;
  final void Function(String)? onRoomTap;

  const TeacherScheduleCard({
    super.key,
    required this.items,
    this.title = 'Schedule for Today',
    this.onItemTap,
    this.onSectionTap,
    this.onRoomTap,
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
              return GestureDetector(
                onTap: () => onItemTap?.call(it),
                child: Container(
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
                            child: SizedBox(
                              height: 20,
                              child: Marquee(
                                text: it.subjectName,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
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

                      // **IMPROVEMENT**: Chips are now horizontally scrollable
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (it.sectionName != null && it.sectionName!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: _InfoChip(
                                  icon: Icons.group,
                                  label: it.sectionName!,
                                  onTap: () => onSectionTap?.call(it.sectionName!),
                                ),
                              ),
                            if (it.room != null && it.room!.trim().isNotEmpty)
                              _InfoChip(
                                icon: Icons.meeting_room,
                                label: 'Room ${it.room!}',
                                onTap: () => onRoomTap?.call(it.room!),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
  final void Function(ScheduleItem)? onItemTap;
  final void Function(String instructorId, String professorName)? onProfessorTap;
  final void Function(String)? onSectionTap;
  final void Function(String)? onRoomTap;

  const StudentScheduleCard({
    super.key,
    required this.items,
    this.title = 'Schedule for Today',
    this.onItemTap,
    this.onProfessorTap,
    this.onSectionTap,
    this.onRoomTap,
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
              return GestureDetector(
                onTap: () => onItemTap?.call(it),
                child: Container(
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
                            child: SizedBox(
                              height: 20,
                              child: Marquee(
                                text: it.subjectName,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
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

                      // **IMPROVEMENT**: Chips are now horizontally scrollable
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (it.professor.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: _InfoChip(
                                  icon: Icons.person,
                                  label: it.professor,
                                  onTap: () {
                                    if (it.instructorId != null) {
                                      onProfessorTap?.call(it.instructorId!, it.professor);
                                    }
                                  },
                                ),
                              ),
                            if (it.room != null && it.room!.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: _InfoChip(
                                  icon: Icons.meeting_room,
                                  label: 'Room ${it.room!}',
                                  onTap: () => onRoomTap?.call(it.room!),
                                ),
                              ),
                            if (it.sectionName != null && it.sectionName!.trim().isNotEmpty)
                              _InfoChip(
                                icon: Icons.group,
                                label: it.sectionName!,
                                onTap: () => onSectionTap?.call(it.sectionName!),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
          Expanded(
            child: _SideBorderCard(
              height: 140,
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
  final VoidCallback? onTap;

  const _InfoChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
        color: Theme.of(context).colorScheme.surface,
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

// ============================ DIALOGS & PANELS ============================

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
                color: Theme.of(context).colorScheme.surface,
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

// --- Content Widgets for SlidingPanel ---

class LoadingContent extends StatelessWidget {
  const LoadingContent({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Fetching details...'),
          ],
        ),
      ),
    );
  }
}

class ErrorContent extends StatelessWidget {
  final String error;
  const ErrorContent({super.key, required this.error});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 16),
            Text('Failed to load details.\n$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class ScheduleDetailContent extends StatelessWidget {
  final ScheduleItem item;
  const ScheduleDetailContent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow(context, Icons.schedule, '${item.startTime} - ${item.endTime}'),
        if (item.professor.isNotEmpty)
          _buildDetailRow(context, Icons.person, item.professor),
        if (item.room != null && item.room!.isNotEmpty)
          _buildDetailRow(context, Icons.meeting_room, 'Room ${item.room}'),
        if (item.sectionName != null && item.sectionName!.isNotEmpty)
          _buildDetailRow(context, Icons.group, item.sectionName!),
        if (item.courseName != null && item.courseName!.isNotEmpty)
          _buildDetailRow(context, Icons.school, item.courseName!),
      ],
    );
  }
}

class InstructorDetailsContent extends StatelessWidget {
  final InstructorDetails details;
  const InstructorDetailsContent({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (details.photoURL != null)
          CircleAvatar(
            radius: 40,
            backgroundImage: NetworkImage(details.photoURL!),
            onBackgroundImageError: (_, __) {},
            backgroundColor: Colors.grey[200],
          )
        else
          const CircleAvatar(
            radius: 40,
            child: Icon(Icons.person, size: 40),
          ),
        const SizedBox(height: 16),
        _buildDetailRow(context, Icons.person, details.fullName),
        if (details.departmentName != null)
          _buildDetailRow(context, Icons.school, details.departmentName!),
      ],
    );
  }
}

class SectionRosterContent extends StatelessWidget {
  final List<SectionStudent> students;
  const SectionRosterContent({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      child: students.isEmpty
          ? const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text('No students found for this section.'),
      ))
          : ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: student.photoURL != null ? NetworkImage(student.photoURL!) : null,
                onBackgroundImageError: student.photoURL != null ? (_, __) {} : null,
                backgroundColor: Colors.grey.shade200,
                child: student.photoURL == null ? Icon(Icons.person_outline, color: Colors.grey.shade600) : null,
              ),
              title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }
}

class RoomScheduleContent extends StatelessWidget {
  final List<ScheduleItem> schedules;
  const RoomScheduleContent({super.key, required this.schedules});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      child: schedules.isEmpty
          ? const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text('No classes scheduled in this room today.'),
      ))
          : ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: schedules.length,
        itemBuilder: (context, index) {
          final s = schedules[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, Icons.schedule, '${s.startTime} - ${s.endTime}'),
                  _buildDetailRow(context, Icons.person_outline, s.professor),
                  _buildDetailRow(context, Icons.group, s.sectionName ?? 'N/A'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildDetailRow(BuildContext context, IconData icon, String text, {double verticalPadding = 6.0}) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: verticalPadding),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

// ============================ MARQUEE WIDGET ============================

class Marquee extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double blankSpace;
  final double velocity;

  const Marquee({
    super.key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.blankSpace = 75.0,
    this.velocity = 50.0,
  });

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _startScrolling();
        }
      });
    });
  }

  void _startScrolling() {
    if (!mounted || !_scrollController.hasClients) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    final needsScroll = maxScrollExtent > 0;

    if (!needsScroll) return;

    final scrollDuration = Duration(milliseconds: (maxScrollExtent / widget.velocity * 1000).toInt());

    _timer?.cancel();
    _timer = Timer.periodic(scrollDuration + widget.pauseDuration, (timer) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        maxScrollExtent,
        duration: scrollDuration,
        curve: Curves.linear,
      ).then((_) {
        if (mounted) {
          Future.delayed(widget.pauseDuration, () {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0)
            SizedBox(width: widget.blankSpace),
        ],
      ),
    );
  }
}

// ============================ Skeleton Loading ============================


class ScheduleSkeletonLoading extends StatelessWidget {
  final int itemCount;

  const ScheduleSkeletonLoading({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skeleton for title
        Container(
          width: 150,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),

        // Skeleton items
        ...List.generate(itemCount, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildSkeletonItem(context),
        )),
      ],
    );
  }

  Widget _buildSkeletonItem(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Subject name skeleton
              Container(
                width: 180,
                height: 18,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Time skeleton
              Container(
                width: 100,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chips skeleton
          Row(
            children: [
              Container(
                width: 90,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 110,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Add this class as well for the full page skeleton
class HomeSkeletonLoading extends StatelessWidget {
  const HomeSkeletonLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 180,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tag chips skeleton
          Row(
            children: [
              Container(
                width: 90,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 110,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Date and notes boxes skeleton
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Schedule skeleton
          ScheduleSkeletonLoading(),
        ],
      ),
    );
  }
}