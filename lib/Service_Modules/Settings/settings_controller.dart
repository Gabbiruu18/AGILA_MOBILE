import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../Screens/Theme/agila_theme.dart';
import 'settings_service.dart';

enum NotifSound { system, chime, bell, pop }

extension NotifSoundX on NotifSound {
  String get key => name; // for SharedPreferences
  static NotifSound parse(String s) =>
      NotifSound.values.firstWhere((e) => e.name == s, orElse: () => NotifSound.system);

  /// Asset path for preview (null for 'system' since that's OS tone)
  String? get assetPath => switch (this) {
    NotifSound.system => null,
    NotifSound.chime  => 'assets/sounds/chime.mp3',
    NotifSound.bell   => 'assets/sounds/bell.mp3',
    NotifSound.pop    => 'assets/sounds/pop.mp3',
  };

  /// Android raw resource name (no extension) if you mirror files to res/raw
  String? get androidRaw => switch (this) {
    NotifSound.system => null,
    _ => name, // chime/bell/pop
  };
}

class SettingsController extends ChangeNotifier {

  final SettingsService _svc;
  final AudioPlayer _player = AudioPlayer();
  bool _isBusy = false;            // e.g. uploading image, saving contact

  NotifSound selectedSound = NotifSound.system;

  SettingsController({SettingsService? service}) : _svc = service ?? SettingsService();

  Future<void> load() async {
    final saved = await _svc.getNotificationSound();
    selectedSound = NotifSoundX.parse(saved ?? 'system');
    notifyListeners();
  }

  Future<void> setSound(NotifSound s) async {
    selectedSound = s;
    await _svc.setNotificationSound(s.key);
    notifyListeners();
  }

  Future<void> preview() async {
    final asset = selectedSound.assetPath;
    if (asset == null) return; // system tone can't be previewed as an asset
    await _player.stop();
    await _player.play(AssetSource(asset));
  }


  // add inside _ProfileScreenState
  Future<bool> _confirmLogout(BuildContext ctx) async {
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        //backgroundColor: Color(0xFFFFFFFF),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Color(0xFF9A0017)),
            SizedBox(width: 8),
            Text('Confirm logout'),
          ],
        ),
        content: const Text("You'll be signed out of AGILA. Continue?"),
        actions: [
          // Cancel (Text color)
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            style: TextButton.styleFrom(
              foregroundColor: kAgilaBlue, // <- text color
            ),
            child: const Text('Cancel'),
          ),
          // Confirm (FilledButton color)
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Color(0xFF9A0017), // <- filled button color
              foregroundColor: Colors.white,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    return result ?? false;
  }


  Future<void> logout(BuildContext context) async {
    // 1) Ask first
    final ok = await _confirmLogout(context);
    if (ok != true) return;

    // 2) Proceed with sign out
    _setBusy(true);
    try {
      await _svc.signOut();

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    } finally {
      _setBusy(false);
    }
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
