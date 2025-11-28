import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:project_agila/Screens/UI_Screen/bottom_nav.dart';
import '../../Service_Modules/Login/auth_m.dart';
import '../../Service_Modules/Login/biometric_util.dart';
import 'terms.dart';

class QuickLoginScreen extends StatefulWidget {
  const QuickLoginScreen({super.key});

  @override
  State<QuickLoginScreen> createState() => _QuickLoginScreenState();
}

class _QuickLoginScreenState extends State<QuickLoginScreen> {
  String? rememberedEmail;
  String? rememberedUid;
  String greeting = 'Magandang Araw!';
  String displayName = '';
  bool _termsAccepted = false;
  bool _isBiometricAvailableForThisUser = false;
  bool _isLoading = false;
  final TextEditingController pinController = TextEditingController();

  static const _assetPath = 'assets/images/agila_opening.png';


  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _updateFCMToken(String role, String uid) async {
    try {
      final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
      final String? newToken = await _firebaseMessaging.getToken();

      if (newToken != null) {
        debugPrint('FCM Token for quick login: $newToken');

        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(role)
            .collection('accounts')
            .doc(uid);

        final userDoc = await docRef.get();

        if (!userDoc.exists || userDoc.data()?['fcmToken'] != newToken) {
          debugPrint('FCM Token is new or has been refreshed. Updating in Firestore.');
          await docRef.update({
            'fcmToken': newToken,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('FCM token updated successfully');
        }
      }
    } catch (e) {
      debugPrint('Error updating FCM token during quick login: $e');
    }
  }

  Future<void> _loadInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('rememberedEmail');
    final uid = prefs.getString('rememberedUid');
    final terms = prefs.getBool('termsAccepted') ?? false;

    if (uid == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/');
      return;
    }

    final hasEnabledBiometrics = prefs.getBool('biometric_enabled_for_uid_$uid') ?? false;
    final canCheckBiometrics = await BiometricUtil.checkBiometricAvailability();

    setState(() {
      rememberedEmail = email;
      rememberedUid = uid;
      _termsAccepted = terms;
      _isBiometricAvailableForThisUser = hasEnabledBiometrics && canCheckBiometrics;
    });

    await _fetchUserDetailsFromFirestore(uid);
  }

  Future<void> _fetchUserDetailsFromFirestore(String uid) async {
    try {
      const roles = ['student', 'teacher', 'program_head'];
      DocumentSnapshot<Map<String, dynamic>>? userDoc;

      for (final role in roles) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(role).collection('accounts').doc(uid).get();
        if (doc.exists) {
          userDoc = doc;
          break;
        }
      }

      if (userDoc == null || !userDoc.exists) {
        if (mounted) setState(() => displayName = 'User');
        return;
      }

      final data = userDoc.data()!;
      final firstName = data['firstName'] ?? '';
      final lastName = data['lastName'] ?? '';
      final composedName = '$firstName $lastName'.trim();

      if (mounted) {
        setState(() {
          displayName = composedName.isNotEmpty ? composedName : (rememberedEmail?.split('@').first ?? 'User');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => displayName = rememberedEmail?.split('@').first ?? 'User');
      }
    }
  }

  Future<void> _handleSwitchAccount() async {
    if (_isLoading || rememberedUid == null) return;

    setState(() => _isLoading = true);

    try {
      const roles = ['student', 'teacher', 'program_head'];
      String? userRole;
      for (final role in roles) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(role).collection('accounts').doc(rememberedUid!).get();
        if (doc.exists) {
          userRole = role;
          break;
        }
      }

      if (userRole != null && mounted) {
        await AuthServices.logout(context, userRole, rememberedUid!);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('rememberMe');
        await prefs.remove('rememberedEmail');
        await prefs.remove('rememberedUid');
        if (mounted) Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      debugPrint("Error switching account: $e");
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _biometricLogin() async {
    if (_isLoading) return;
    if (!_termsAccepted) { _showTermsDialog(); return; }

    final authenticated = await BiometricUtil.authenticateWithFingerprint(context);
    if (authenticated && mounted) {
      await _performQuickLogin();
    }
  }

  void _showPasscodeDialog() {
    if (_isLoading) return;
    if (!_termsAccepted) { _showTermsDialog(); return; }

    pinController.clear();
    final cs = Theme.of(context).colorScheme;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: GoogleFonts.poppins(fontSize: 22, color: cs.onSurface),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: cs.primary, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: cs.primaryContainer,
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter Passcode", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              "Enter your 6-digit passcode to login.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Pinput(
              controller: pinController,
              length: 6,
              autofocus: true,
              obscureText: true,
              obscuringCharacter: '●',
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              onCompleted: (pin) {
                Navigator.pop(context);
                _performQuickLogin(enteredPasscode: pin);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _performQuickLogin({String? enteredPasscode}) async {
    if (rememberedUid == null) return;

    setState(() => _isLoading = true);

    try {
      const roles = ['student', 'teacher', 'program_head'];
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      String? userRole;
      for (final role in roles) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(role).collection('accounts').doc(rememberedUid!).get();
        if (doc.exists) {
          userDoc = doc;
          userRole = role;
          break;
        }
      }

      if (userDoc == null || !userDoc.exists || userRole == null) {
        throw Exception("User data not found. Please login again.");
      }

      final userData = userDoc.data()!;
      bool authorized = false;

      if (enteredPasscode != null) {
        final storedPasscode = userData['passcode'] as String?;
        if (enteredPasscode == storedPasscode) {
          authorized = true;
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect Passcode")));
        }
      } else {
        authorized = true;
      }

      if (authorized && mounted) {
        await _updateFCMToken(userRole!, rememberedUid!);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainLayout(
              role: userRole!,
              name: '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
              uid: rememberedUid!,
              faceRegistered: userData['faceRegistered'] ?? false,
              academicYearId: userData['academicYearId'] ?? '',
              acadYear: userData['acadYear'] ?? '',
              semesterId: userData['semesterId'] ?? '',
              semesterName: userData['semesterName'] ?? '',
              firstName: userData['firstName'] ?? '',
              lastName: userData['lastName'] ?? '',
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Welcome back, $displayName!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Quick login failed: ${e.toString()}")));
      await _handleSwitchAccount();
    } finally {
      if (mounted) {
        pinController.clear();
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TermsDialog(),
    ).then((_) {
      _loadInitialState();
    });
  }

  Future<void> _toggleTerms(bool? value) async {
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('termsAccepted', value);
    setState(() => _termsAccepted = value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
                  Text('AI-Guided Identification and Logging Classroom Monitoring Attendance', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary ,fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 36),
                  Text(greeting, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary ,fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(displayName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.primary ,fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    width: double.infinity,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(blurRadius: 4, offset: const Offset(0, 2))]),
                    child: Text(rememberedEmail ?? 'No email found', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13)),
                  ),
                  const SizedBox(height: 10),
                  TextButton(onPressed: _handleSwitchAccount, child: Text('Switch Account', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLoginCard(icon: Icons.dialpad, label: 'Passcode\nLogin', onTap: _showPasscodeDialog),
                      if (_isBiometricAvailableForThisUser) ...[
                        const SizedBox(width: 16),
                        _buildLoginCard(icon: Icons.fingerprint, label: 'Biometrics\nLogin', onTap: _biometricLogin),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(value: _termsAccepted, activeColor: cs.primary, onChanged: _toggleTerms),
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
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginCard({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(blurRadius: 4, offset: const Offset(0, 2))]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}