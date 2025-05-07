import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_agila/Screens/UI_Screen/home.dart';
import 'package:project_agila/Screens/UI_Screen/profile.dart';
import 'package:google_fonts/google_fonts.dart';

class MainLayout extends StatefulWidget {
  final String role;
  final String name;
  final String uid;

  const MainLayout({
    super.key,
    required this.role,
    required this.name,
    required this.uid,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    HomeScreen(role: widget.role, name: widget.name),
    const Center(child: Text('Attendance Page')),
    const Center(child: Text('Request Page')),
    ProfileScreen(role: widget.role, uid: widget.uid),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF0058CE),
        unselectedItemColor: const Color(0xFFC88000),
        selectedLabelStyle: GoogleFonts.poppins(),
        unselectedLabelStyle: GoogleFonts.poppins(),
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Request'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
