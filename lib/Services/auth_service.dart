import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';
import 'package:project_agila/Utils/biometric_util.dart';

class AuthServices {
  static Future<void> login(String email, String password, BuildContext context) async {
    try {
      debugPrint("Attempting login for: $email");

      // Step 1: Try signing in
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user == null) throw FirebaseAuthException(code: 'no-user', message: 'User is null');

      final uid = user.uid;
      final roles = ['student', 'faculty', 'program_head', 'academic_head'];
      String? role;
      bool faceRegistered = false;
      Map<String, dynamic>? userData;

      // Step 2: Look for user document
      for (final r in roles) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(r)
            .collection('accounts')
            .doc(uid)
            .get();

        if (doc.exists) {
          debugPrint("✅ Found user in role: $r");
          role = r;
          userData = doc.data();
          faceRegistered = userData?['faceRegistered'] ?? false;
          break;
        }
      }

      // Step 3: If not found in any role
      if (role == null || userData == null) {
        debugPrint("❌ Firestore user document not found for UID: $uid");
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login failed: No Firestore data found for this user.")),
        );
        return;
      }

      // Step 4: Welcome dialog or facial registration
      if (faceRegistered) {
        debugPrint("✅ Face already registered. Showing welcome dialog.");

        ScaffoldMessenger.of(context).showSnackBar( // Show success *before* opening dialog
          SnackBar(content: Text("Welcome, ${user.email}! Login Successful")),
        );

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Welcome!"),
            content: Text("Welcome, ${userData?['firstName']} ${userData?['lastName']}!"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        debugPrint("🟡 Face not registered. Redirecting to facial registration.");
        Navigator.pushReplacementNamed(context, '/facial-registration', arguments: {
          'uid': uid,
          'role': role,
          'name': '${userData['firstName']} ${userData['lastName']}',
        });

        // Only show snackbar here
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome, ${user.email}! Login Successful")),
        );
      }

      // Step 5: Fingerprint (safe zone)
      try {
        bool isRegistered = await DatabaseService.isFingerprintRegistered(uid);
        if (!isRegistered) {
          bool registerFingerprint = await _showRegisterFingerprintDialog(context);
          if (registerFingerprint) {
            await DatabaseService.saveFingerprintRegistration(uid);
          }
        }
      } catch (fingerprintError) {
        debugPrint("⚠️ Fingerprint setup error: $fingerprintError");
      }

    } catch (e) {
      if (e is FirebaseAuthException) {
        debugPrint("FirebaseAuthException: ${e.code} | ${e.message}");
      } else {
        debugPrint("Unexpected login error: $e");
      }

      // Final catch for actual failed login
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
