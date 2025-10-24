import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

class BiometricUtil {
  static final LocalAuthentication auth = LocalAuthentication();

  static Future<bool> checkBiometricAvailability() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isDeviceSupported = await auth.isDeviceSupported();
      debugPrint('Can check biometrics: $canCheckBiometrics');
      debugPrint('Device supports biometrics: $isDeviceSupported');
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      debugPrint("Error checking biometric availability: $e");
      return false;
    }
  }

  static Future<bool> authenticateWithFingerprint(BuildContext context) async {
    // Check for availability first
    final isAvailable = await checkBiometricAvailability();
    debugPrint('Biometric availability: $isAvailable');

    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric authentication is not available on this device.")),
        );
      }
      return false;
    }

    // Get available biometrics
    List<BiometricType> availableBiometrics = [];
    try {
      availableBiometrics = await auth.getAvailableBiometrics();
      debugPrint('Available biometrics: $availableBiometrics');

      if (availableBiometrics.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No biometrics enrolled on this device. Please set up fingerprint in your device settings.")),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint("Error getting available biometrics: $e");
      return false;
    }

    // Additional delay to ensure UI is ready
    await Future.delayed(const Duration(milliseconds: 500));

    bool authenticated = false;
    try {
      debugPrint("Attempting to show biometric authentication dialog...");

      // Force showing the fingerprint dialog even if active
      authenticated = await auth.authenticate(
        localizedReason: "Scan your fingerprint to authenticate",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      debugPrint("Biometric authentication result: $authenticated");
    } catch (e) {
      debugPrint("Biometric authentication error: $e");

      // Handle specific errors
      String errorMessage = "Authentication error";
      if (e is PlatformException) {
        switch (e.code) {
          case auth_error.notAvailable:
            errorMessage = "Biometrics not available on this device";
            break;
          case auth_error.notEnrolled:
            errorMessage = "No biometrics enrolled on this device";
            break;
          case auth_error.lockedOut:
            errorMessage = "Biometrics locked out due to too many attempts";
            break;
          case auth_error.permanentlyLockedOut:
            errorMessage = "Biometrics permanently locked. Please unlock your device first";
            break;
          case auth_error.passcodeNotSet:
            errorMessage = "Device security is not enabled";
            break;
          default:
            errorMessage = "Authentication error: ${e.message}";
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }

    return authenticated;
  }
}