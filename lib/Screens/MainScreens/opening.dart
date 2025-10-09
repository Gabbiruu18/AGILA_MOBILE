import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  OpeningScreenState createState() => OpeningScreenState();
}

class OpeningScreenState extends State<OpeningScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  static const _assetPath = 'assets/images/agila_opening.png';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
    _navigate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _navigate();
    }
  }

  Future<bool> _checkFirestoreForPasscode(String uid) async {
    const roles = ['student', 'teacher', 'program_head'];
    for (final role in roles) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(role)
            .collection('accounts')
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data.containsKey('passcode') && (data['passcode'] as String).isNotEmpty) {
            // Found a passcode, so we can quick login.
            return true;
          }
        }
      } catch (e) {
        // Log error or handle it, but don't block navigation.
        debugPrint("Error checking for passcode in Firestore: $e");
      }
    }
    return false;
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    final rememberedUid = prefs.getString('rememberedUid');

    bool canQuickLogin = false;
    if (rememberMe && rememberedUid != null) {
      // 1. Check for biometrics enabled on this device (fastest check).
      final hasBiometrics = prefs.getBool('biometric_enabled_for_uid_$rememberedUid') ?? false;

      // 2. Check for a passcode. This is more reliable as it checks Firestore.
      final hasPasscode = await _checkFirestoreForPasscode(rememberedUid);

      // If EITHER ONE is true, the user can use the quick login screen.
      if (hasPasscode || hasBiometrics) {
        canQuickLogin = true;
      }
    }

    if (canQuickLogin) {
      Navigator.pushReplacementNamed(context, '/quick-login');
    } else {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_assetPath), context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(_assetPath, width: 200, fit: BoxFit.contain, filterQuality: FilterQuality.high),
        ),
      ),
    );
  }
}