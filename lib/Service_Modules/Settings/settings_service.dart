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

  // --- NEW: Biometrics Methods ---
  Future<bool> getBiometricStatus(String uid) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('biometric_enabled_for_uid_$uid') ?? false;
  }

  Future<void> setBiometricStatus(String uid, {required bool enabled}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('biometric_enabled_for_uid_$uid', enabled);
    if (enabled) {
      // If user explicitly enables it, remove the 'skipped' flag
      await p.remove('biometric_setup_skipped_for_uid_$uid');
    }
  }

  // --- NEW: Passcode Methods ---
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
    await auth.signOut();
  }
}