import 'package:flutter/widgets.dart';
import 'theme_controller.dart';

/// Lightweight way to access ThemeController anywhere without extra packages.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final scope =
    context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found. Wrap your app with ThemeScope.');
    return scope!.notifier!;
  }
}
