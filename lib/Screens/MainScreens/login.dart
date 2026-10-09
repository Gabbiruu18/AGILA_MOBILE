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
  bool _isCheckingTerms = true;

  static const _assetPath = 'assets/images/agila_opening.png';

  @override
  void initState() {
    super.initState();
    _checkTermsAndShowDialog();
  }

  Future<void> _checkTermsAndShowDialog() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final termsAccepted = prefs.getBool('termsAccepted') ?? false;
    setState(() {
      _termsAccepted = termsAccepted;
    });

    if (!termsAccepted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const TermsDialog(),
      );
      final newTermsAccepted = prefs.getBool('termsAccepted') ?? false;
      if (mounted) {
        setState(() {
          _termsAccepted = newTermsAccepted;
          _isCheckingTerms = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isCheckingTerms = false;
        });
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TermsDialog(),
    ).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if(mounted) {
        setState(() {
          _termsAccepted = prefs.getBool('termsAccepted') ?? false;
        });
      }
    });
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
    if (_isCheckingTerms) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      _assetPath,
                      width: 150,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AI-Guided Identification and Logging Classroom Monitoring Attendance',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).colorScheme.primary),
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
                          activeColor: Theme.of(context).colorScheme.primary,
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
                          activeColor: Theme.of(context).colorScheme.primary,
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
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
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
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest, width: 2),
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
          backgroundColor: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isLoading
            ? null
            : () async {
          FocusScope.of(context).unfocus();
          if (!_termsAccepted) {
            _showTermsDialog();
            return;
          }

          setState(() => _isLoading = true);

          await AuthServices.login(
            idController.text.trim(),
            passwordController.text.trim(),
            _rememberMe,
            context,
          );

          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
        child: Text('LOGIN', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}