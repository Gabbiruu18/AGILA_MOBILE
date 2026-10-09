import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_agila/Service_Modules/Notification/notification.dart';
import 'package:project_agila/Service_Modules/Home/home_controller.dart';
import 'package:project_agila/Service_Modules/Home/home_UI.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  final String uid;
  final String firstName;
  final String lastName;
  final String name;


  const HomeScreen({
    Key? key,
    required this.role,
    required this.uid,
    required this.firstName,
    required this.lastName,
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
    controller.init(
      role: widget.role,
      uid: widget.uid,
    );
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

  void _showScheduleDetails(ScheduleItem item) {
    _showSlidingPanel(
      title: item.subjectName,
      content: ScheduleDetailContent(item: item),
    );
  }

  void _onSectionChipTapped(String sectionName) {
    _showSlidingPanelWithFuture(
      title: 'Student list for $sectionName',
      future: controller.viewSectionRoster(sectionName),
      builder: (data) => SectionRosterContent(students: data ?? []),
    );
  }

  void _onProfessorChipTapped(String instructorId, String professorName) {
    _showSlidingPanelWithFuture(
      title: 'Instructor Profile',
      future: controller.viewInstructorDetails(instructorId),
      builder: (data) {
        if (data == null) {
          return ErrorContent(error: 'Could not find details for $professorName.');
        }
        return InstructorDetailsContent(details: data);
      },
    );
  }

  void _onRoomChipTapped(String roomName) {
    _showSlidingPanelWithFuture(
      title: 'Today\'s Schedule for Room $roomName',
      future: controller.viewRoomSchedule(roomName),
      builder: (data) => RoomScheduleContent(schedules: data ?? []),
    );
  }

  void _showSlidingPanel({required String title, required Widget content}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SlidingPanel(title: title, child: content),
    );
  }

  void _showSlidingPanelWithFuture<T>({
    required String title,
    required Future<T> future,
    required Widget Function(T? data) builder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<T>(
          future: future,
          builder: (context, snapshot) {
            Widget content;
            if (snapshot.connectionState == ConnectionState.waiting) {
              content = const LoadingContent();
            } else if (snapshot.hasError) {
              content = ErrorContent(error: snapshot.error.toString());
            } else {
              content = builder(snapshot.data);
            }
            return SlidingPanel(title: title, child: content);
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedMonthYear = DateFormat('MMMM yyyy').format(now);
    final formattedDay = DateFormat('EEEE').format(now);
    final formattedDayNumber = DateFormat('d').format(now);

    return Scaffold(
      body: SafeArea(
        child: controller.isLoading
            ? const HomeSkeletonLoading()
            : RefreshIndicator(
          onRefresh: controller.refreshToday,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeaderBar(
                  greeting: _greeting(),
                  name: controller.name,
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
                  child: _buildScheduleSection(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    if (controller.isLoadingSchedules) {
      return const ScheduleSkeletonLoading();
    }

    if (controller.schedulesError != null) {
      return Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Failed to Load Schedules',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[800]),
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.schedulesError}\n\nPlease check the debug console for more details.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
            ],
          ),
        ),
      );
    }
    return controller.isTeacherOrHead
        ? TeacherScheduleCard(
      items: controller.todaySchedules,
      title: 'Schedule for Today',
      onItemTap: _showScheduleDetails,
      onSectionTap: _onSectionChipTapped,
      onRoomTap: _onRoomChipTapped,
    )
        : StudentScheduleCard(
      items: controller.todaySchedules,
      title: 'Schedule for Today',
      onItemTap: _showScheduleDetails,
      onSectionTap: _onSectionChipTapped,
      onProfessorTap: _onProfessorChipTapped,
      onRoomTap: _onRoomChipTapped,
    );
  }

}