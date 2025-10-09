import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_agila/Screens/Theme/agila_theme.dart';
import 'package:project_agila/Service_Modules/Login//biometric_util.dart';
import 'settings_service.dart';

// Sound enum remains the same...
enum NotifSound { system, chime, bell, pop }
extension NotifSoundX on NotifSound {
  String get key => name;
  static NotifSound parse(String s) => NotifSound.values.firstWhere((e) => e.name == s, orElse: () => NotifSound.system);
  String? get assetPath => switch (this) { NotifSound.system => null, NotifSound.chime => 'assets/sounds/chime.mp3', NotifSound.bell => 'assets/sounds/bell.mp3', NotifSound.pop => 'assets/sounds/pop.mp3' };
  String? get androidRaw => switch (this) { NotifSound.system => null, _ => name };
}

class SettingsController extends ChangeNotifier {
  final SettingsService _svc;
  final AudioPlayer _player = AudioPlayer();
  bool _isBusy = false;

  // Existing properties
  NotifSound selectedSound = NotifSound.system;

  // --- NEW: Quick Login State ---
  bool hasPasscode = false;
  bool hasBiometrics = false;
  bool canCheckBiometrics = false;
  String? _uid;
  String? _role;

  SettingsController({SettingsService? service}) : _svc = service ?? SettingsService();

  Future<void> load() async {
    _isBusy = true;
    notifyListeners();

    // Load sound settings
    final savedSound = await _svc.getNotificationSound();
    selectedSound = NotifSoundX.parse(savedSound ?? 'system');

    // --- NEW: Load Quick Login Settings ---
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _uid = user.uid;
      final passcodeStatus = await _svc.getPasscodeStatus(_uid!);
      hasPasscode = passcodeStatus['hasPasscode'];
      _role = passcodeStatus['role'];

      canCheckBiometrics = await BiometricUtil.checkBiometricAvailability();
      if (canCheckBiometrics) {
        hasBiometrics = await _svc.getBiometricStatus(_uid!);
      }
    }

    _isBusy = false;
    notifyListeners();
  }

  // Sound methods remain the same...
  Future<void> setSound(NotifSound s) async {
    selectedSound = s;
    await _svc.setNotificationSound(s.key);
    notifyListeners();
  }

  Future<void> preview() async {
    final asset = selectedSound.assetPath;
    if (asset == null) return;
    await _player.stop();
    await _player.play(AssetSource(asset));
  }

  // --- NEW: Quick Login Logic ---
  Future<void> toggleBiometrics(BuildContext context, {required bool value}) async {
    if (!canCheckBiometrics || _uid == null) return;

    bool success = false;
    if (value) { // Turning on
      final authenticated = await BiometricUtil.authenticateWithFingerprint(context);
      if (authenticated) {
        await _svc.setBiometricStatus(_uid!, enabled: true);
        hasBiometrics = true;
        success = true;
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometrics enabled")));
      }
    } else { // Turning off
      await _svc.setBiometricStatus(_uid!, enabled: false);
      hasBiometrics = false;
      success = true;
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometrics disabled")));
    }

    if (success) notifyListeners();
  }

  Future<void> removePasscode(BuildContext context) async {
    if (_uid == null || _role == null) return;

    await _svc.removePasscode(_uid!, _role!);
    hasPasscode = false;
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passcode removed")));
    notifyListeners();
  }

  // Logout methods remain the same...
  Future<void> logout(BuildContext context) async {
    final ok = await _confirmLogout(context);
    if (ok != true) return;
    _setBusy(true);
    try {
      await _svc.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> _confirmLogout(BuildContext ctx) async {
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Row(children: const [Icon(Icons.logout, color: Color(0xFF9A0017)), SizedBox(width: 8), Text('Confirm logout')]),
        content: const Text("You'll be signed out of AGILA. Continue?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), style: TextButton.styleFrom(foregroundColor: kAgilaBlue), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogCtx, true), style: FilledButton.styleFrom(backgroundColor: Color(0xFF9A0017), foregroundColor: Colors.white), child: const Text('Log out')),
        ],
      ),
    );
    return result ?? false;
  }

  void _setBusy(bool v) {
    if (_isBusy != v) {
      _isBusy = v;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}