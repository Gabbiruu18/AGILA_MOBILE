import 'package:flutter/material.dart';
import 'package:project_agila/Screens/Theme/theme_scope.dart';
import 'package:project_agila/Screens/Theme/theme_controller.dart';
import 'package:project_agila/Service_Modules/Settings/settings_controller.dart';

Future<bool?> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late ThemeController _themeCtrl;
  late final SettingsController _settingsCtrl;

  @override
  void initState() {
    super.initState();
    _settingsCtrl = SettingsController()..load(); // This now loads everything
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
      animation: Listenable.merge([_themeCtrl, _settingsCtrl]), // Only listen to these two
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

              // --- Quick Login Settings ---
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