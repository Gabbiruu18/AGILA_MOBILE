import 'package:flutter/material.dart';
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

  static const _assetPath = 'assets/images/agila_opening.png';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    // Opacity should be 0..1
    _fadeAnimation = Tween<double>(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Navigate to the correct screen after a delay
    Future.delayed(const Duration(seconds: 6), () async {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache for a smoother first paint
    precacheImage(const AssetImage(_assetPath), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            _assetPath,
            width: 200,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
