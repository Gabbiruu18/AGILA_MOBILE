import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Services/auth_service.dart';
import '../Utils/biometric_util.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isBiometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    bool available = await BiometricUtil.checkBiometricAvailability();
    setState(() {
      _isBiometricAvailable = available;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'A',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFBB43C),
                      ),
                    ),
                    TextSpan(
                      text: 'GILA',
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0058CE),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI-Driven General Identification and Logging Attendance',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF0045A2)),
              ),
              const SizedBox(height: 32),
              _buildTextField("Identification NO.", idController, ""),
              const SizedBox(height: 16),
              _buildTextField("Password", passwordController, "", isPassword: true),
              const SizedBox(height: 24),
              _buildLoginButton(),
              const SizedBox(height: 16),
              if (_isBiometricAvailable) _buildBiometricButtons(),
              const SizedBox(height: 16),
              _buildSignupLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hintText, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(color: const Color(0x67001A3E)), // Label color
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0058CE), width: 2), // Blue border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFAFAFAF), width: 2),
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        )
            : null,
      ),
    );
  }


  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0058CE),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => AuthServices.login(idController.text.trim(), passwordController.text.trim(), context),
        child: Text('LOGIN', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildBiometricButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.face, size: 40, color: Color(0xFF0058CE)),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Face Login is still in development.")));
          },
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.fingerprint, size: 40, color: Color(0xFF0058CE)),
          onPressed: () => BiometricUtil.authenticateWithFingerprint(context),
        ),
      ],
    );
  }

  Widget _buildSignupLink() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/signup'),
      child: RichText(
        text: TextSpan(
          text: 'No Account? ',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
          children: [
            TextSpan(text: 'Click Here', style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFFFBB43C))),
          ],
        ),
      ),
    );
  }
}
