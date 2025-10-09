import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_agila/Screens/UI_Screen/bottom_nav.dart';
import 'package:project_agila/Service_Modules/Login//biometric_util.dart';

class AuthServices {
  static Future<void> login(String email, String password, bool rememberMe, BuildContext context) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      if (!context.mounted) return;

      User? user = userCredential.user;
      if (user == null) throw FirebaseAuthException(code: 'no-user', message: 'User is null');

      final uid = user.uid;
      final roles = ['student', 'teacher', 'program_head'];
      String? role;
      Map<String, dynamic>? userData;

      for (final r in roles) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(r).collection('accounts').doc(uid).get();
        if (doc.exists) {
          role = r;
          userData = doc.data();
          break;
        }
      }

      if (userData == null || role == null) throw Exception("User data or role not found in Firestore.");

      final prefs = await SharedPreferences.getInstance();

      // --- THE FIX: Await the dialog to ensure it's seen before navigating ---
      bool faceRegistered = userData['faceRegistered'] ?? false;
      bool hasBeenNotified = prefs.getBool('face_reg_notified_for_uid_$uid') ?? false;

      if (!faceRegistered && !hasBeenNotified) {
        String authority = "your designated authority";
        switch (role) {
          case 'student':
          case 'teacher':
          case 'program_head':
            authority = "MIS";
            break;
        }

        if (context.mounted) {
          // By 'awaiting' this, we ensure the code pauses until the user clicks OK.
          await showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text("Facial Registration Incomplete"),
              content: Text("Your account is not yet registered for facial recognition. Please see $authority to complete your setup."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          // After the user clicks OK and the dialog closes, save the flag.
          await prefs.setBool('face_reg_notified_for_uid_$uid', true);
        }
      }

      // --- Continue with login regardless of face registration status ---
      if (rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('rememberedEmail', email);
        await prefs.setString('rememberedUid', uid);
      } else {
        await prefs.remove('rememberMe');
        await prefs.remove('rememberedEmail');
        await prefs.remove('rememberedUid');
        await prefs.remove('passcode_enabled_for_uid_$uid');
        await prefs.remove('biometric_enabled_for_uid_$uid');
      }

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainLayout(role: role!, name: '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}', uid: uid, faceRegistered: faceRegistered, academicYearId: '', acadYear: '', semesterId: '', semesterName: '', firstName: '', lastName: '')));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Welcome, ${user.email}! Login Successful")));
      if (!context.mounted) return;

      // Quick login setup prompts...
      final hasPasscode = userData.containsKey('passcode') && (userData['passcode'] as String? ?? '').isNotEmpty;
      final passcodeSetupSkipped = prefs.getBool('passcode_setup_skipped_for_uid_$uid') ?? false;

      if (!hasPasscode && !passcodeSetupSkipped) {
        await _promptPinSetup(context, uid, role);
      }

      final hasBiometrics = prefs.getBool('biometric_enabled_for_uid_$uid') ?? false;
      final biometricSetupSkipped = prefs.getBool('biometric_setup_skipped_for_uid_$uid') ?? false;
      final canCheckBiometrics = await BiometricUtil.checkBiometricAvailability();

      if (!hasBiometrics && !biometricSetupSkipped && canCheckBiometrics) {
        final enableBiometric = await _showRegisterFingerprintDialog(context);
        if (!context.mounted) return;
        if (enableBiometric) {
          final authenticated = await BiometricUtil.authenticateWithFingerprint(context);
          if (authenticated) {
            await prefs.setBool('biometric_enabled_for_uid_$uid', true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric login enabled!")));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric setup cancelled.")));
          }
        } else {
          await prefs.setBool('biometric_setup_skipped_for_uid_$uid', true);
        }
      }

    } on FirebaseAuthException catch (e) {
      String message = "Login Failed: An unknown error occurred.";
      if (e.code == 'user-not-found' || e.code == 'invalid-email') message = "Login Failed: No user found with that email.";
      else if (e.code == 'wrong-password' || e.code == 'invalid-credential') message = "Login Failed: Incorrect password.";
      else if (e.code == 'network-request-failed') message = "Login Failed: Please check your network connection.";
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: An unexpected error occurred.")));
    }
  }

  // _promptPinSetup and _showRegisterFingerprintDialog methods remain the same...
  static Future<void> _promptPinSetup(BuildContext context, String uid, String role) async {
    final pinController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 52,
      textStyle: TextStyle(fontSize: 22, color: cs.onSurface),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Set Quick Login Passcode"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Set a 6-digit passcode for faster login on any device."),
            const SizedBox(height: 24),
            Pinput(
              controller: pinController,
              length: 6,
              autofocus: true,
              obscureText: true,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme.copyWith(
                decoration: defaultPinTheme.decoration!.copyWith(
                  border: Border.all(color: cs.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('passcode_setup_skipped_for_uid_$uid', true);
              Navigator.pop(dialogContext);
            },
            child: const Text("Skip"),
          ),
          FilledButton(
            onPressed: () async {
              final passcode = pinController.text.trim();
              if (passcode.length == 6) {
                await FirebaseFirestore.instance.collection('users').doc(role).collection('accounts').doc(uid).update({'passcode': passcode});

                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('passcode_enabled_for_uid_$uid', true);
                await prefs.remove('passcode_setup_skipped_for_uid_$uid');

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode saved successfully!")));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode must be 6 digits.")));
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  static Future<bool> _showRegisterFingerprintDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enable Biometric Login?"),
        content: const Text("Would you like to use your fingerprint for faster login on this device?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("No, Thanks")),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Yes, Enable")),
        ],
      ),
    ) ?? false;
  }
}