import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';

class VerifyEmailScreen extends StatefulWidget {
  final User user;

  const VerifyEmailScreen({Key? key, required this.user}) : super(key: key);

  @override
  VerifyEmailScreenState createState() => VerifyEmailScreenState();
}

class VerifyEmailScreenState extends State<VerifyEmailScreen>
    with TickerProviderStateMixin {
  bool isVerified = false;
  bool isChecking = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _iconBounceController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    // Fade Animation
    _fadeController =
    AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Pop-Up Animation (Scaling Effect)
    _scaleController =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _scaleAnimation =
        Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(
          parent: _scaleController,
          curve: Curves.elasticOut,
        ));

    // Bounce Animation for Check Icon
    _iconBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Rotation Animation for Hourglass
    _rotationController =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    // Send verification email
    widget.user.sendEmailVerification();
    startCheckingVerification();
  }

  void startCheckingVerification() async {
    while (!isVerified && isChecking) {
      await Future.delayed(const Duration(seconds: 3));
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        setState(() {
          isVerified = true;
          isChecking = false;
        });

        _scaleController.forward();
        _iconBounceController.stop();
        _rotationController.stop();

        await Future.delayed(const Duration(seconds: 5));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        break;
      }
    }
  }

  Future<void> cancelRegistration() async {
    await widget.user.delete();
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _iconBounceController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pop-Up Animation for Title
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Text(
                      isVerified ? "Email Verified" : "Verify Email",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0058CE),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Verification Message
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    isVerified
                        ? "Your email is now verified.\nYou will now proceed to facial registration."
                        : "A verification link has been sent to your email:\n${widget.user.email}",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Animated Icon Transition
              AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                child: isVerified
                    ? ScaleTransition(
                  scale: _scaleAnimation,
                  child: Icon(
                    Icons.check_circle,
                    key: const ValueKey(1),
                    color: Colors.green,
                    size: 80,
                  ),
                )
                    : RotationTransition(
                  turns: _rotationController,
                  child: Icon(
                    Icons.hourglass_top,
                    key: const ValueKey(2),
                    color: Colors.grey,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Cancel Button (Hides when email is verified)
              if (!isVerified)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0058CE),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: cancelRegistration,
                  child: Text(
                    "Cancel",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
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
