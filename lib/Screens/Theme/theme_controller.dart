import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central theme state (Light / Dark / System) with persistence.
class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'themeMode'; // 'system' | 'light' | 'dark'

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Call once at startup (e.g., in main before runApp).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    switch (saved) {
      case 'light':
        _mode = ThemeMode.light;
        break;
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      default:
        _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Set a specific mode and persist.
  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
    notifyListeners();
  }

  /// Quick toggle: flips Light <-> Dark (ignores System).
  void toggleLightDark() {
    final next = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setMode(next);
  }

  /// Optional: cycle System → Light → Dark → System.
  void cycle() {
    final next = switch (_mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light  => ThemeMode.dark,
      ThemeMode.dark   => ThemeMode.system,
    };
    setMode(next);
  }

  /// Effective brightness for places where you need a bool immediately.
  bool isDark(BuildContext context) {
    return switch (_mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
      MediaQuery.of(context).platformBrightness == Brightness.dark,
    };
  }
}
