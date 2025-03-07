import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'terms.dart';
import 'verify_email.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _selectedCampus;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _campuses = [
    "STI College Manila",
    "STI College Quezon Avenue",
    "STI College Ortigas-Cainta",
    "STI College Global City",
    "STI College Makati",
    "STI College Caloocan",
    "STI College Alabang",
    "STI College Cubao",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const TermsDialog(),
      );
    });
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyEmailScreen(user: user),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Signup failed")),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFD9D9D9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 30, color: Colors.black),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0058CE)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildInputField(_firstNameController, 'First Name'),
                      _buildInputField(_lastNameController, 'Last Name'),
                      _buildInputField(_idController, 'Identification No.'),
                      _buildInputField(_emailController, 'School Email', isEmail: true),
                      _buildInputField(_mobileController, 'Mobile No.', isNumber: true),
                      _buildInputField(_passwordController, 'Password', isPassword: true),
                      _buildInputField(_confirmPasswordController, 'Confirm Password',
                          isPassword: true, isConfirmPassword: true),

                      const SizedBox(height: 10),


                      Text(
                        "STI College Campus",
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0045A2)),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedCampus,
                          items: _campuses.map((campus) {
                            return DropdownMenuItem(
                              value: campus,
                              child: Text(campus, style: GoogleFonts.poppins(fontSize: 16)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCampus = value;
                            });
                          },
                          decoration: const InputDecoration(border: InputBorder.none),
                          validator: (value) => value == null ? "Please select a campus" : null,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0058CE),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isLoading ? null : _signUp,
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text('Next',
                                style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint,
      {bool isPassword = false, bool isEmail = false, bool isNumber = false, bool isConfirmPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hint,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0045A2))),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            obscureText: isPassword
                ? _obscurePassword
                : isConfirmPassword
                ? _obscureConfirmPassword
                : false,
            keyboardType: isEmail
                ? TextInputType.emailAddress
                : isNumber
                ? TextInputType.phone
                : TextInputType.text,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade400),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              suffixIcon: isPassword || isConfirmPassword
                  ? IconButton(
                icon: Icon(
                  isPassword
                      ? (_obscurePassword ? Icons.visibility_off : Icons.visibility)
                      : (_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    if (isPassword) {
                      _obscurePassword = !_obscurePassword;
                    } else {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    }
                  });
                },
              )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return "Field cannot be empty";
              if (isEmail &&
                  !RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$').hasMatch(value)) {
                return "Enter a valid email";
              }
              if (isPassword && value.length < 6) return "Password must be at least 6 characters";
              if (isConfirmPassword && value != _passwordController.text) {
                return "Passwords do not match";
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
