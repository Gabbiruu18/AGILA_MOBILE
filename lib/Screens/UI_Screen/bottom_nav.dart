import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_agila/Screens/UI_Screen/home.dart';
import 'package:project_agila/Screens/UI_Screen/profile.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:project_agila/Screens/UI_Screen/request.dart';
import 'package:project_agila/Screens/UI_Screen/attendance.dart';
import 'package:project_agila/Screens/UI_Screen/schedule.dart';
import 'package:project_agila/Screens/Theme/agila_theme.dart';

class MainLayout extends StatefulWidget {
  final String role;
  final String name;
  final String uid;

  const MainLayout({
    super.key,
    required this.role,
    required this.name,
    required this.uid,
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
        r == 'program_head' || r == 'program' ||
        r == 'academic_head' || r == 'academic';
  }

  List<Widget> get _screens => [
    HomeScreen(role: widget.role, name: widget.name, uid: widget.uid),
    _isStaffRole
        ? ScheduleScreen(uid: widget.uid, role: widget.role)
        : const AttendanceScreen(),
    RequestListScreen(uid: widget.uid, role: widget.role, name: widget.name),
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
