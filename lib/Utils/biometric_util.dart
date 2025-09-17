import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BiometricUtil {
  static final LocalAuthentication auth = LocalAuthentication();

  static Future<bool> checkBiometricAvailability() async {
    return await auth.canCheckBiometrics || await auth.isDeviceSupported();
  }

  static Future<bool> authenticateWithFingerprint(BuildContext context) async {
    bool authenticated = false;

    try {
      authenticated = await auth.authenticate(
        localizedReason: "Scan your fingerprint to login",
        options: const AuthenticationOptions(biometricOnly: true),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Biometric Authentication Error")),
      );
    }

    return authenticated;
  }

  static Future<String?> getRegisteredUserEmail() async {
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('fingerprintRegistered', isEqualTo: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first["firstName" + "lastName"]; // For retrieving the user's email
    }
    return null;
  }
}
