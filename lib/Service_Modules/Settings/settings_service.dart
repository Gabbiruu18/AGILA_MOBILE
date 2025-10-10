import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  static const String _soundKey = 'notif_sound';

  SettingsService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  Future<String?> getNotificationSound() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_soundKey);
  }

  Future<void> setNotificationSound(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_soundKey, value);
  }

  // --- ADDED: Notification Preference Methods ---
  Future<bool> getNotificationStatus(String uid, String role) async {
    final doc = await firestore.collection('users').doc(role).collection('accounts').doc(uid).get();
    if (doc.exists) {
      // Default to true (on) if the field doesn't exist yet.
      return doc.data()?['notificationsEnabled'] ?? true;
    }
    // Also default to true if the document somehow can't be found.
    return true;
  }

  Future<void> setNotificationStatus(String uid, String role, {required bool enabled}) async {
    await firestore
        .collection('users')
        .doc(role)
        .collection('accounts')
        .doc(uid)
        .update({'notificationsEnabled': enabled});
  }
  // --- END ADDED ---

  // --- Biometrics Methods ---
  Future<bool> getBiometricStatus(String uid) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('biometric_enabled_for_uid_$uid') ?? false;
  }

  Future<void> setBiometricStatus(String uid, {required bool enabled}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('biometric_enabled_for_uid_$uid', enabled);
    if (enabled) {
      await p.remove('biometric_setup_skipped_for_uid_$uid');
    }
  }

  // --- Passcode Methods ---
  Future<Map<String, dynamic>> getPasscodeStatus(String uid) async {
    const roles = ['student', 'teacher', 'program_head'];
    for (final role in roles) {
      final doc = await firestore.collection('users').doc(role).collection('accounts').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final hasPasscode = data.containsKey('passcode') && (data['passcode'] as String? ?? '').isNotEmpty;
        return {'hasPasscode': hasPasscode, 'role': role};
      }
    }
    return {'hasPasscode': false, 'role': null};
  }

  Future<void> removePasscode(String uid, String role) async {
    await firestore.collection('users').doc(role).collection('accounts').doc(uid).update({'passcode': ''});
    final p = await SharedPreferences.getInstance();
    await p.setBool('passcode_enabled_for_uid_$uid', false);
  }

  Future<void> signOut() async {
    final user = auth.currentUser;
    if (user == null) {
      // If there's no user, just sign out to be safe.
      await auth.signOut();
      return;
    }

    final uid = user.uid;

    // We need to find the user's role to know where their document is.
    const roles = ['student', 'teacher', 'program_head'];
    for (final role in roles) {
      final docRef = firestore.collection('users').doc(role).collection('accounts').doc(uid);
      final doc = await docRef.get();

      if (doc.exists) {
        // Found the user! Now, delete their fcmToken.
        print("User found in role '$role'. Deleting FCM token before logout.");
        await docRef.update({
          'fcmToken': FieldValue.delete(), // This completely removes the field
        });
        // We found the user and deleted the token, so we can stop looking.
        break;
      }
    }

    // Finally, sign the user out of the Firebase authentication system.
    await auth.signOut();
  }
}