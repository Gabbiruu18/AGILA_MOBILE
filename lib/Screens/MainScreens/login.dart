import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Service_Modules/Login/auth_m.dart';
import 'terms.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController idController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _termsAccepted = false;
  bool _rememberMe = false;
  bool _isLoading = false;

  static const _assetPath = 'assets/images/agila_opening.png';


  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _termsAccepted = prefs.getBool('termsAccepted') ?? false;
    });

    if (!_termsAccepted) {
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const TermsDialog(),
        );
      });
    }
  }

  Future<void> _toggleTerms(bool? value) async {
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('termsAccepted', value);
    setState(() {
      _termsAccepted = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    _assetPath,
                    width: 150,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  /*RichText(
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
                  ),*/
                  const SizedBox(height: 4),
                  Text(
                    'AI-Driven General Identification and Logging Attendance',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF0045A2)),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField("School Email", idController, "example.000000@caloocan.sti.edu.ph"),
                  const SizedBox(height: 16),
                  _buildTextField("Password", passwordController, "", isPassword: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFF0058CE),
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? false;
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      Text("Remember Me", style: GoogleFonts.poppins(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLoginButton(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        activeColor: const Color(0xFF0058CE),
                        onChanged: _toggleTerms,
                      ),
                      const SizedBox(width: 4),
                      Text("I accept the terms and conditions", style: GoogleFonts.poppins(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF0058CE))),
            ),
        ],
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
        hintStyle: const TextStyle(color: Color(0xFFBFBFBF)),
        labelStyle: const TextStyle(color: Color(0x67001A3E)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0058CE), width: 2),
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
        onPressed: _isLoading
            ? null
            : () async {
          FocusScope.of(context).unfocus();
          if (!_termsAccepted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const TermsDialog(),
            );
            return;
          }

          setState(() {
            _isLoading = true;
          });

          if (_rememberMe) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('rememberMe', true);
            await prefs.setString('rememberedEmail', idController.text.trim());
          }

          await AuthServices.login(
            idController.text.trim(),
            passwordController.text.trim(),
            context,
          );

          setState(() {
            _isLoading = false;
          });
        },
        child: Text('LOGIN',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}