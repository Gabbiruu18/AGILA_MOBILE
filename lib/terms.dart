import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  }

  void _checkIfScrolledToEnd() {
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 20) { // Small offset for better accuracy
      if (!_isScrolledToEnd) {
        setState(() {
          _isScrolledToEnd = true;
        });
      }
    }
  }

  void _handleBackAction() {
    if (!_isChecked) {
      // If terms are not accepted, close both TermsDialog and SignUpScreen
      Navigator.pop(context); // Close TermsDialog
      Navigator.pop(context); // Close SignUpScreen
    } else {
      Navigator.pop(context); // Close only TermsDialog
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBackAction();
        return false; // Prevent default back button behavior
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Container(
          height: 500, // Adjust height as needed
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Title
              Text(
                "Terms and Conditions",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              // Scrollable Terms Content
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

                        // Checkbox: Accept Terms (Placed at the end of the terms text)
                        Row(
                          children: [
                            Checkbox(
                              value: _isChecked,
                              activeColor: const Color(0xFFFBB43C), // Custom color when checked
                              onChanged: _isScrolledToEnd
                                  ? (value) {
                                setState(() {
                                  _isChecked = value!;
                                });
                              }
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                "I accept the terms and conditions",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black, // Ensure readability
                                ),
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

              // Close Button (Disabled until checkbox is checked)
              ElevatedButton(
                onPressed: _isChecked ? () => Navigator.pop(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isChecked ? Colors.blue : Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  "Close",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
