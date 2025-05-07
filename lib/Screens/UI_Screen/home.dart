import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_agila/Screens/UI_Screen/profile.dart'; 

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatelessWidget {
  final String role;
  final String name;

  const HomeScreen({super.key, required this.role, required this.name});


  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedMonthYear = DateFormat('MMMM yyyy').format(now);
    final formattedDay = DateFormat('EEEE').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(name),
                      const SizedBox(height: 16),
                      _buildTopBoxes(formattedMonthYear, formattedDay),
                      const SizedBox(height: 24),
                      _buildSchedule(role),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Magandang Araw!',
                style: GoogleFonts.poppins(color: const Color(0xFFC88000), fontSize: 14),
              ),
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0058CE),
                ),
              ),
            ],
          ),
          const Icon(Icons.notifications_none, color: Color(0xFFC88000), size: 28),
        ],
      ),
    );
  }

  Widget _buildTopBoxes(String monthYear, String day) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Container(
              height: 130,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0058CE), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(monthYear, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(HttpHeaders.dateHeader, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(day, style: GoogleFonts.poppins()),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 130,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0058CE), width: 2),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'To do list\n(user can input a note)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedule(String role) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCHEDULE FOR TODAY',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0058CE),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0058CE), width: 2),
            ),
            child: Column(
              children: List.generate(3, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${index + 1}st Sub', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      Text('(Professor)', style: GoogleFonts.poppins()),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Time', style: GoogleFonts.poppins()),
                          Text('Time', style: GoogleFonts.poppins()),
                        ],
                      ),
                      if (index < 2) const Divider(),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }



}
