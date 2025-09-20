import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Service_Modules/Login/auth_m.dart';
import '../../Utils/biometric_util.dart';
import 'terms.dart';

class QuickLoginScreen extends StatefulWidget {
  const QuickLoginScreen({super.key});

  @override
  State<QuickLoginScreen> createState() => _QuickLoginScreenState();
}

class _QuickLoginScreenState extends State<QuickLoginScreen> {
  String? rememberedEmail;
  String greeting = 'Magandang Araw!';
  String displayName = '';
  bool _termsAccepted = false;
  TextEditingController pinController = TextEditingController();



  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('rememberedEmail');
    final terms = prefs.getBool('termsAccepted') ?? false;

    setState(() {
      rememberedEmail = email;
      _termsAccepted = terms;
    });

    if (email != null) {
      await _fetchUserDetailsFromFirestore(email);
    }
  }


  Future<void> _fetchUserDetailsFromFirestore(String email) async {
    try {
      final db = FirebaseFirestore.instance;

      // 1) Try emailLower (case-insensitive) in collectionGroup
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await db
            .collectionGroup('accounts')
            .where('emailLower', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();
      } on FirebaseException catch (e) {
        // If an index is required or field missing, fall back to 'email'
        // debugPrint('emailLower query failed: $e');
        snap = await db
            .collectionGroup('accounts')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
      }

      // 2) If still empty, probe known roles directly (no collectionGroup needed)
      if (snap.docs.isEmpty) {
        const roles = ['student', 'teacher', 'program_head', 'academic_head'];
        for (final role in roles) {
          final q = await db
              .collection('users').doc(role)
              .collection('accounts')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            snap = q;
            break;
          }
        }
      }

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        setState(() => displayName = ''); // nothing found
        return;
      }

      final data = snap.docs.first.data();

      // Helper to safely pick a string from possible field names
      String? pick(List<String> keys) {
        for (final k in keys) {
          final v = data[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return null;
      }

      final disp  = pick(['displayName', 'display_name', 'fullName', 'full_name', 'name']);
      final first = pick(['firstName', 'first_name', 'firstname', 'givenName', 'given_name']);
      final last  = pick(['lastName', 'last_name', 'lastname', 'familyName', 'family_name']);

      String composed = disp ?? [first, last].where((s) => s != null && s.isNotEmpty).join(' ').trim();
      if (composed.isEmpty) {
        // last resort: show the local part of the email
        composed = email.split('@').first;
      }

      if (!mounted) return;
      setState(() {
        displayName = composed;
      });
    } catch (e) {
      // debugPrint('Fetch quick-login name failed: $e');
      if (!mounted) return;
      setState(() {
        // still show something instead of blank
        displayName = email.split('@').first;
      });
    }
  }




  Future<void> _clearRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rememberMe');
    await prefs.remove('rememberedEmail');
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _biometricLogin() async {
    if (!_termsAccepted) {
      _showTermsDialog();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('rememberedEmail');
    final fingerprintRegistered = prefs.getBool('fingerprintRegistered') ?? false;

    if (email == null || !fingerprintRegistered) return;

    final authenticated = await BiometricUtil.authenticateWithFingerprint(context);
    if (authenticated) {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('accounts')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final userData = snapshot.docs.first.data();
        final password = userData['password'];
        if (password != null) {
          await AuthServices.login(email, password, context);
        }
      }
    }
  }

  void _showPinDialog() {
    pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 24), // Adjusted width
          child: SizedBox(
            height: 120,
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        bool isFilled = index < pinController.text.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? const Color(0xFF0058CE) : Colors.transparent,
                            border: Border.all(color: const Color(0xFF0058CE), width: 2),
                          ),
                        );
                      }),
                    ),

                    // Hidden input for typing
                    Opacity(
                      opacity: 0.0,
                      child: TextField(
                        controller: pinController,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onChanged: (value) async {
                          setState(() {});
                          if (value.length == 6) {
                            Navigator.pop(context);
                            final prefs = await SharedPreferences.getInstance();
                            final storedPin = prefs.getString('userPIN');

                            if (storedPin == value.trim() && rememberedEmail != null) {
                              final snapshot = await FirebaseFirestore.instance
                                  .collectionGroup('accounts')
                                  .where('email', isEqualTo: rememberedEmail)
                                  .limit(1)
                                  .get();

                              if (snapshot.docs.isNotEmpty) {
                                final userData = snapshot.docs.first.data();
                                final password = userData['password'];
                                if (password != null) {
                                  await AuthServices.login(rememberedEmail!, password, context);
                                }
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Incorrect PIN")),
                              );
                            }
                            pinController.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TermsDialog(),
    );
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      //backgroundColor: const Color(0xFFF6F7FB),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary ,fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 32),

              Text(
                greeting,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary ,fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              /*Text(
                displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary ,fontSize: 16, fontWeight: FontWeight.w700),
              ),*/
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  rememberedEmail ?? 'No email found',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),

              TextButton(
                onPressed: _clearRememberedUser,
                child: Text(
                  'Switch Account',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w700)
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLoginCard(
                    icon: Icons.dialpad,
                    label: 'PIN\nLogin',
                    onTap: _showPinDialog,
                  ),
                  const SizedBox(width: 16),
                  _buildLoginCard(
                    icon: Icons.fingerprint,
                    label: 'Biometrics\nLogin',
                    onTap: _biometricLogin,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Terms checkbox
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    activeColor: cs.primary,
                    onChanged: _toggleTerms,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "I accept the terms and conditions",
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard({

    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
