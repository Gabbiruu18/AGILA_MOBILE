import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
// Removed 'package:cloud_firestore/cloud_firestore.dart' as it's no longer needed.

class BiometricUtil {
  static final LocalAuthentication auth = LocalAuthentication();

  static Future<bool> checkBiometricAvailability() async {
    try {
      // z
      return await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (e) {
      // In case of any platform errors, log it and return false.
      debugPrint("Error checking biometric availability: $e");
      return false;
    }
  }

  static Future<bool> authenticateWithFingerprint(BuildContext context) async {
    // --- 1. IMPROVED ROBUSTNESS: Check for availability first ---
    final isAvailable = await checkBiometricAvailability();
    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric authentication is not available on this device.")),
        );
      }
      return false;
    }

    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: "Scan your fingerprint to login",
        options: const AuthenticationOptions(
          biometricOnly: true, // Only allow biometric (e.g., fingerprint, face ID)
          stickyAuth: true,    // Keep the dialog open on app switch
        ),
      );
    } catch (e) {
      debugPrint("Biometric authentication error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An error occurred during biometric authentication.")),
        );
      }
    }

    return authenticated;
  }

// --- 2. REMOVED INSECURE METHOD ---
// The `getRegisteredUserEmail()` function was removed.
// It was based on a flawed pattern. The new, secure architecture in `quick_login.dart`
// uses the locally stored `rememberedUid` and `rememberedEmail`, making this method obsolete.
}