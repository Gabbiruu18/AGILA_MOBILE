import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:project_agila/Screens/UI_Screen/notification.dart';
import 'package:project_agila/Service_Modules/Home/home_controller.dart';
import 'package:project_agila/Service_Modules/Home/home_UI.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  final String uid;
  final String name;

  const HomeScreen({
    Key? key,
    required this.role,
    required this.uid,
    required this.name,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController controller;

  @override
  void initState() {
    super.initState();
    controller = HomeController();
    controller.addListener(_onChanged);
    controller.init(role: widget.role, uid: widget.uid, name: widget.name);
  }

  @override
  void dispose() {
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h <= 11) return 'Magandang Umaga!';
    if (h >= 12 && h <= 16) return 'Magandang Hapon!';
    return 'Magandang Gabi!';
  }

  void _openNotesDialog() {
    final textController = TextEditingController(
      text: controller.noteText == 'Tap to write notes' ? '' : controller.noteText,
    );

    showDialog(
      context: context,
      builder: (context) => NotesDialog(
        controller: textController,
        onReset: () async {
          await controller.resetNote(context);
          if (mounted) Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
        onSave: () async {
          await controller.saveNote(context, textController.text);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedMonthYear = DateFormat('MMMM yyyy').format(now);
    final formattedDay = DateFormat('EEEE').format(now);
    final formattedDayNumber = DateFormat('d').format(now);

    // Decide which schedule UI to use
    final isTeacherOrHead = widget.role == 'teacher' ||
        widget.role == 'program_head' ||
        widget.role == 'academic_head';

// Dummy schedule list (same as before; you can keep your source of truth)


    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderBar(
                greeting: _greeting(),
                name: widget.name,
                role: widget.role,
                courseName: controller.course,
                sectionName: controller.section,
                departmentName: controller.departmentRaw,
                unreadCount: controller.unreadCount,
                onOpenNotifications: () {
                  showDialog(
                    context: context,
                    builder: (context) => NotificationModal(uid: widget.uid, role: widget.role),
                  );
                },
              ),

              const SizedBox(height: 8),

              TopBoxes(
                monthYear: formattedMonthYear,
                day: formattedDay,
                dayNumber: formattedDayNumber,
                onEditNotes: _openNotesDialog,
                noteText: controller.noteText,
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: isTeacherOrHead
                    ? TeacherScheduleCard(
                  items: controller.todaySchedules,
                  title: 'Schedule for Today',
                )
                    : StudentScheduleCard(
                  items: controller.todaySchedules,
                  title: 'Schedule for Today',
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}