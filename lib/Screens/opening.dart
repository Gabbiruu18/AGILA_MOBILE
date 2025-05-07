import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  OpeningScreenState createState() => OpeningScreenState();
}

class OpeningScreenState extends State<OpeningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Navigate to the correct screen after a delay
    Future.delayed(const Duration(seconds: 5), () async {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        rememberMe ? '/quick-login' : '/',
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                shadows: [
                  const Shadow(
                    offset: Offset(3, 3),
                    blurRadius: 2,
                    color: Colors.black45,
                  ),
                ],
              ),
              children: [
                const TextSpan(
                  text: 'A',
                  style: TextStyle(color: Color(0xFFFFA000)), // Orange
                ),
                const TextSpan(
                  text: 'GILA',
                  style: TextStyle(color: Color(0xFF0058CE)), // Blue
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
