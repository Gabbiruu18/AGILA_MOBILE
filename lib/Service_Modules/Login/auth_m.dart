import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_agila/Screens/UI_Screen/bottom_nav.dart';
import 'package:project_agila/Service_Modules/Login/biometric_util.dart';

class AuthServices {
  // This function gets the device's token and saves it to Firestore.
  static Future<void> _getAndSaveFCMToken(String role, String uid) async {
    try {
      // First check if "Remember Me" is enabled
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      // Added debugging
      debugPrint('Remember Me status: $rememberMe');
      debugPrint('Attempting to get FCM token for user $uid with role $role');

      // Only proceed if "Remember Me" is enabled
      if (!rememberMe) {
        debugPrint('Remember Me not checked - FCM token will not be saved');
        return;
      }

      final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
      // Make sure to request permission BEFORE getting token
      NotificationSettings settings = await firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final String? token = await firebaseMessaging.getToken();

        if (token != null) {
          debugPrint('FCM Token received: $token');

          // Try/catch specifically for the Firestore operation
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(role)
                .collection('accounts')
                .doc(uid)
                .update({
              'fcmToken': token,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('FCM token successfully saved to Firestore');
          } catch (firestoreError) {
            debugPrint('Error saving FCM token to Firestore: $firestoreError');
          }
        } else {
          debugPrint('FCM Token is null');
        }
      } else {
        debugPrint('Notification permission denied');
      }
    } catch (e) {
      debugPrint('Error getting or saving FCM token: $e');
    }
  }

  // Method to explicitly clean up FCM token when needed
  static Future<void> cleanupFCMToken(String role, String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(role)
          .collection('accounts')
          .doc(uid)
          .update({
        'fcmToken': FieldValue.delete(), // Remove the field completely
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM token removed for user: $uid in role: $role');
    } catch (e) {
      debugPrint('Error cleaning up FCM token: $e');
    }
  }

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
      await prefs.setBool('rememberMe', rememberMe);
      if (rememberMe) {
        await prefs.setString('rememberedEmail', email);
        await prefs.setString('rememberedUid', uid);
      } else {
        await prefs.remove('rememberedEmail');
        await prefs.remove('rememberedUid');
      }

      // Save FCM token only after we have the user role and if "Remember Me" is checked
      await _getAndSaveFCMToken(role, uid);

      bool passcodeSetupSkipped = prefs.getBool('passcode_setup_skipped_for_uid_$uid') ?? false;
      bool passcodeEnabled = prefs.getBool('passcode_enabled_for_uid_$uid') ?? false;
      bool hasPasscodeInFirestore = userData.containsKey('passcode') && (userData['passcode'] as String).isNotEmpty;


      if (!context.mounted) return;

      if (userData['faceRegistered'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainLayout(
              role: role!,
              name: '${userData!['firstName'] ?? ''} ${userData['lastName'] ?? ''}',
              uid: uid,
              academicYearId: userData['academicYearId'] ?? '',
              acadYear: userData['acadYear'] ?? '',
              faceRegistered: userData['faceRegistered'] ?? false,
              firstName: userData['firstName'] ?? '',
              lastName: userData['lastName'] ?? '',
              semesterId: userData['semesterId'] ?? '',
              semesterName: userData['semesterName'] ?? '',
            ),
          ),
        );
      } else {
        await _promptFaceIDSetup(context, uid, role);
      }

      if (!passcodeSetupSkipped && !passcodeEnabled && !hasPasscodeInFirestore) {
        if (!context.mounted) return;
        await _promptPinSetup(context, uid, role);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Successful! Welcome, ${userData['firstName']}.")));
    } on FirebaseAuthException catch (e) {
      String message = "Login Failed: An unknown error occurred.";
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        message = "Login Failed: No user found with that email.";
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = "Login Failed: Incorrect email or password.";
      } else if (e.code == 'network-request-failed') {
        message = "Login Failed: Please check your network connection.";
      }
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: An unexpected error occurred. ${e.toString()}")));
    }
  }

  // Improved biometric registration method with better error handling

  // Add an explicit logout method (uses the existing one from settings_service.dart)
  static Future<void> logout(BuildContext context, String role, String uid) async {
    try {
      // Clean up FCM token first
      await cleanupFCMToken(role, uid);

      // Then sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rememberMe');
      await prefs.remove('rememberedEmail');
      await prefs.remove('rememberedUid');

      // Navigate back to login
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logout error: ${e.toString()}")),
        );
      }
    }
  }

  static Future<void> _promptPinSetup(BuildContext context, String uid, String role) async {
    final pinController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 52,
      textStyle: TextStyle(fontSize: 20, color: cs.onSurface, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Setup Passcode"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("For quick login, please set up a 6-digit passcode."),
            const SizedBox(height: 16),
            Pinput(
              controller: pinController,
              length: 6,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: defaultPinTheme.copyWith(decoration: defaultPinTheme.decoration!.copyWith(border: Border.all(color: cs.primary, width: 2))),
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode saved successfully!")));
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode must be 6 digits.")));
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

Future<void> _promptFaceIDSetup(BuildContext context, String uid, String role) async {
  final canAuthenticate = await BiometricUtil.checkBiometricAvailability();
  if (!canAuthenticate) return;

  if(!context.mounted) return;
  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Enable Biometric Login"),
      content: const Text("Would you like to enable biometric login for faster access?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("No"),
        ),
        FilledButton(
          onPressed: () async {
            final success = await BiometricUtil.authenticateWithFingerprint(context);
            if (success) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('biometric_enabled_for_uid_$uid', true);
              Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric login enabled!")));
              }
            }
          },
          child: const Text("Yes"),
        ),
      ],
    ),
  );
}