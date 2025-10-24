import 'package:flutter/material.dart';
import 'package:project_agila/Screens/Theme/theme_scope.dart';
import 'package:project_agila/Screens/Theme/theme_controller.dart';
import 'package:project_agila/Service_Modules/Settings/settings_controller.dart';

// ✅ CHANGED: accept role and uid
Future<bool?> showSettingsSheet(BuildContext context, {required String role, required String uid}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SettingsSheet(role: role, uid: uid), // ✅ CHANGED: pass to widget
  );
}

class _SettingsSheet extends StatefulWidget {
  // ✅ CHANGED: accept role and uid
  final String role;
  final String uid;
  const _SettingsSheet({required this.role, required this.uid});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late ThemeController _themeCtrl;
  late final SettingsController _settingsCtrl;

  @override
  void initState() {
    super.initState();
    // ✅ CHANGED: pass role and uid to controller
    _settingsCtrl = SettingsController()..load(uid: widget.uid, role: widget.role);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _themeCtrl = ThemeScope.of(context);
  }

  @override
  void dispose() {
    _settingsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_themeCtrl, _settingsCtrl]),
      builder: (context, _) {
        final isDark = switch (_themeCtrl.mode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          _ => MediaQuery.of(context).platformBrightness == Brightness.dark,
        };

        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.outlineVariant, borderRadius: BorderRadius.circular(8),
                ),
              ),
              Row(
                children: [
                  const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Card(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: const Text('Dark mode'),
                      subtitle: Text(isDark ? 'On' : 'Off'),
                      value: isDark,
                      onChanged: (on) => _themeCtrl.setMode(on ? ThemeMode.dark : ThemeMode.light),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextButton(
                          onPressed: () => _themeCtrl.setMode(ThemeMode.system),
                          child: const Text('Use system theme'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text("Quick Login", style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                    ),
                    if (_settingsCtrl.canCheckBiometrics)
                      SwitchListTile.adaptive(
                        title: const Text("Use Biometrics"),
                        value: _settingsCtrl.hasBiometrics,
                        onChanged: (value) => _settingsCtrl.toggleBiometrics(context, value: value),
                      ),
                    ListTile(
                      title: const Text("Passcode"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_settingsCtrl.hasPasscode ? "Enabled" : "Not Set", style: TextStyle(color: cs.outline)),
                          const SizedBox(width: 8),
                          if (_settingsCtrl.hasPasscode)
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: () => _settingsCtrl.removePasscode(context),
                              tooltip: "Remove Passcode",
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- ADDED: Notification Settings Card ---
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                    ),
                    SwitchListTile.adaptive(
                      title: const Text("Receive Notifications"),
                      value: _settingsCtrl.notificationsEnabled,
                      onChanged: (value) => _settingsCtrl.toggleNotifications(value),
                    ),
                  ],
                ),
              ),
              // --- END ADDED ---

              Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Logout',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _settingsCtrl.logout(context),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}