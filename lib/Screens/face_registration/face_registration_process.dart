import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FacialRegistrationProcessingScreen extends StatefulWidget {
  const FacialRegistrationProcessingScreen({super.key});

  @override
  State<FacialRegistrationProcessingScreen> createState() => _FacialRegistrationProcessingScreen();
}

class _FacialRegistrationProcessingScreen extends State<FacialRegistrationProcessingScreen> with TickerProviderStateMixin {
  bool _isComplete = false;
  late AnimationController _checkAnimationController;

  @override
  void initState() {
    super.initState();
    _checkAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _simulateProcessing();
  }

  Future<void> _simulateProcessing() async {
    await Future.delayed(const Duration(seconds: 3));
    setState(() {
      _isComplete = true;
    });
    _checkAnimationController.forward();
  }

  @override
  void dispose() {
    _checkAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isComplete)
              const CircularProgressIndicator(color: Color(0xFF0058CE))
            else
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _checkAnimationController,
                  curve: Curves.easeOutBack,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF0058CE), size: 100),
              ),
            const SizedBox(height: 24),
            Text(
              _isComplete ? 'Registration Complete' : 'Processing Registration... Please Wait.',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),
            if (_isComplete)
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0058CE),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Done', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
              )
          ],
        ),
      ),
    );
  }
}
