import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final FirebaseAuth auth;

  static const String _soundKey = 'notif_sound'; // e.g., 'system', 'chime', 'bell', 'pop'

  SettingsService({
    FirebaseAuth? auth,
  })  :
        auth = auth ?? FirebaseAuth.instance;

  Future<String?> getNotificationSound() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_soundKey);
  }

  Future<void> setNotificationSound(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_soundKey, value);
  }

  Future<void> signOut() async {
    await auth.signOut();
  }
}
