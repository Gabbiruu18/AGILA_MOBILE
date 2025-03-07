import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';
import 'package:project_agila/Utils/biometric_util.dart';

class AuthServices {
  static Future<void> login(String email, String password, BuildContext context) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Welcome, ${user.email}! Login Successful")),
        );

        bool isRegistered = await DatabaseService.isFingerprintRegistered(user.uid);
        if (!isRegistered) {
          bool registerFingerprint = await _showRegisterFingerprintDialog(context);
          if (registerFingerprint) await DatabaseService.saveFingerprintRegistration(user.uid);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Failed, Incorrect ID or Password")),
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
              await login(email, password, context); // Login with email & entered password
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
