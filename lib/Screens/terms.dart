import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsDialog extends StatefulWidget {
  const TermsDialog({super.key});

  @override
  TermsDialogState createState() => TermsDialogState();
}

class TermsDialogState extends State<TermsDialog> {
  bool _isChecked = false;
  bool _isScrolledToEnd = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkIfScrolledToEnd);
    _loadInitialState();
  }

  void _checkIfScrolledToEnd() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 20) {
      setState(() {
        _isScrolledToEnd = true;
      });
    }
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isChecked = prefs.getBool('termsAccepted') ?? false;
    });
  }

  Future<void> _setAcceptance(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('termsAccepted', value);
    setState(() {
      _isChecked = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Block dialog from closing if not accepted
        return _isChecked;
      },
      child: Stack(
        children: [
          // 🌀 Background blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withOpacity(0.1)),
          ),

          // 📄 Dialog
          Center(
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Container(
                height: 500,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "Terms and Conditions",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '''
1. Introduction
Welcome to the AI-Driven General Identification and Logging Attendance. By using this system, you agree to the following terms and conditions. Please read them carefully before proceeding.

2. System Overview
This system utilizes AI-powered facial recognition and CCTV technology to automate attendance tracking for institutions and organizations. It enhances accuracy, reduces manual workload, and ensures security compliance.

3. User Responsibilities
3.1. Users must ensure that their face is clearly visible to the CCTV for accurate attendance logging. 
3.2. Any attempt to manipulate or bypass the system, such as using images, videos, or unauthorized access, is strictly prohibited. 
3.3. Users should report any discrepancies in attendance records to the appropriate personnel.

4. Data Privacy and Security
4.1. The system collects and processes facial recognition data solely for attendance monitoring purposes. 
4.2. All personal data is stored securely and is accessible only to authorized personnel. 
4.3. The system complies with applicable data protection laws, including the Data Privacy Act of 2012.
4.4. Users have the right to request access to their attendance records and request corrections if necessary.

5. Acceptance of Terms
By using the AI-Driven CCTV Attendance Monitoring System, you acknowledge that you have read, understood, and agreed to these terms and conditions.
                                ''',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isChecked,
                                    activeColor: const Color(0xFF0058CE),
                                    onChanged: _isScrolledToEnd
                                        ? (val) {
                                      if (val != null) {
                                        _setAcceptance(val);
                                      }
                                    }
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "I accept the terms and conditions",
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Proceed only if accepted
                    ElevatedButton(
                      onPressed: _isChecked
                          ? () => Navigator.pop(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        _isChecked ? const Color(0xFF0058CE) : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Proceed",
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
