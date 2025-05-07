import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Screens/UI_Screen/bottom_nav.dart';
import 'database_service.dart';
import 'package:project_agila/Utils/biometric_util.dart';

class AuthServices {
  static Future<void> login(String email, String password, BuildContext context) async {
    try {
      debugPrint("Attempting login for: $email");

      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user == null) throw FirebaseAuthException(code: 'no-user', message: 'User is null');

      final uid = user.uid;
      final roles = ['student', 'faculty', 'teacher', 'program_head', 'academic_head'];
      String? role;
      bool faceRegistered = false;
      Map<String, dynamic>? userData;

      for (final r in roles) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(r)
            .collection('accounts')
            .doc(uid)
            .get();

        if (doc.exists) {
          role = r;
          userData = doc.data();
          faceRegistered = userData?['faceRegistered'] ?? false;
          break;
        }
      }

      if (role == null || userData == null) {
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login failed: No Firestore data found for this user.")),
        );
        return;
      }

      // ✅ Facial registration check
      // ✅ Facial registration check
      if (!faceRegistered) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainLayout(
              role: role!,
              name: '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}',
              uid: uid,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome, ${user.email}! Login Successful")),
        );
        return;
      }


      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('userPIN')) {
        await _promptPinSetup(context);
      }

// ✅ Prompt for fingerprint registration
      final isFingerprintRegistered = prefs.getBool('fingerprintRegistered') ?? false;
      if (!isFingerprintRegistered) {
        final enableFingerprint = await _showRegisterFingerprintDialog(context);
        if (enableFingerprint) {
          final authenticated = await BiometricUtil.authenticateWithFingerprint(context);
          if (authenticated) {
            await prefs.setBool('fingerprintRegistered', true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Fingerprint not saved. Setup skipped.")),
            );
          }
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainLayout(
            role: role!,
            name: '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}',
            uid: uid,
          ),
        ),
      );


    } catch (e) {
      if (e is FirebaseAuthException) {
        debugPrint("FirebaseAuthException: ${e.code} | ${e.message}");
      } else {
        debugPrint("Unexpected login error: $e");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Failed: Incorrect ID or Password")),
      );
    }
  }



  static Future<void> loginWithFingerprint(BuildContext context) async {
    try {
      bool authenticated = await BiometricUtil.authenticateWithFingerprint(context);

      if (authenticated) {
        String? email = await BiometricUtil.getRegisteredUserEmail();

        if (email != null) {
          _showPasswordInputDialog(context, email);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No registered fingerprint found.")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fingerprint Authentication Failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Biometric Authentication Error")),
      );
    }
  }



  static Future<void> _showPasswordInputDialog(BuildContext context, String email) async {
    TextEditingController passwordController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Password"),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Enter your password"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              String password = passwordController.text.trim();
              Navigator.of(context).pop();
              await login(email, password, context);
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  static Future<void> _promptPinSetup(BuildContext context) async {
    TextEditingController pinController = TextEditingController();
    bool isValid = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Set 6-digit PIN"),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(hintText: "••••••"),
          onChanged: (val) {
            isValid = val.length == 6;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (pinController.text.trim().length == 6) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('userPIN', pinController.text.trim());
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("PIN must be 6 digits.")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }


  static Future<bool> _showRegisterFingerprintDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enable Fingerprint Login?"),
        content: const Text("Would you like to use fingerprint login next time?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }
}
