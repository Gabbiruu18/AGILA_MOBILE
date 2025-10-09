import 'package:flutter/material.dart';
import 'package:project_agila/Screens/UI_Screen/home.dart';
import 'package:project_agila/Screens/UI_Screen/profile.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project_agila/Screens/UI_Screen/request.dart';
import 'package:project_agila/Screens/UI_Screen/attendance.dart';
import 'package:project_agila/Screens/UI_Screen/schedule.dart';

class MainLayout extends StatefulWidget {
  final String role;
  final String name;
  final String firstName;
  final String lastName;
  final String uid;
  final String academicYearId;
  final String acadYear;
  final String semesterId;
  final String semesterName;

  const MainLayout({
    super.key,
    required this.role,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.uid,
    required this.academicYearId,
    required this.acadYear,
    required this.semesterId,
    required this.semesterName,
    required bool faceRegistered,
  });




  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // staff roles use Schedule instead of Attendance
  bool get _isStaffRole {
    final r = widget.role.toLowerCase();
    return r == 'teacher' ||
        r == 'program_head' || r == 'program';
  }

  List<Widget> get _screens => [
    HomeScreen(role: widget.role, name: widget.name, uid: widget.uid, firstName: widget.firstName, lastName: widget.lastName),
    _isStaffRole
        ? ScheduleScreen(uid: widget.uid, role: widget.role, academicYearId: widget.academicYearId, semesterId: widget.semesterId)
    // ✅ FIX: Passed the required uid and role to AttendanceScreen
        : AttendanceScreen(uid: widget.uid, role: widget.role),
    RequestListScreen(uid: widget.uid, role: widget.role, name: widget.name, academicYearId: widget.academicYearId, acadYear: widget.acadYear, semesterId: widget.semesterId, semesterName: widget.semesterName,),
    ProfileScreen(role: widget.role, uid: widget.uid),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.secondary,
        selectedLabelStyle: GoogleFonts.poppins(),
        unselectedLabelStyle: GoogleFonts.poppins(),
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            // icon changes with the label too
            icon: Icon(_isStaffRole ? Icons.calendar_month : Icons.check_circle),
            label: _isStaffRole ? 'Schedule' : 'Attendance',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Request'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}