import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// App pieces
import 'package:project_agila/main.dart' show MyApp;
import 'package:project_agila/Screens/Theme/theme_controller.dart';
import 'package:project_agila/Screens/Theme/theme_scope.dart';
import 'package:project_agila/Screens/MainScreens/opening.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Fresh in-memory prefs for each test run
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Builds MyApp and shows OpeningScreen', (WidgetTester tester) async {
    final themeCtrl = ThemeController();
    await themeCtrl.load();

    await tester.pumpWidget(
      ThemeScope(
        controller: themeCtrl,
        child: MyApp(themeCtrl: themeCtrl),
      ),
    );
    await tester.pumpAndSettle();

    // Assert initial route renders OpeningScreen
    expect(find.byType(OpeningScreen), findsOneWidget);
  });

  testWidgets('Theme toggles via ThemeController', (WidgetTester tester) async {
    final themeCtrl = ThemeController();
    await themeCtrl.load();

    await tester.pumpWidget(
      ThemeScope(
        controller: themeCtrl,
        child: MyApp(themeCtrl: themeCtrl),
      ),
    );
    await tester.pump(); // build once

    // MaterialApp should reflect controller.mode
    var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, themeCtrl.mode);

    // Flip to dark and verify MaterialApp updates
    await themeCtrl.setMode(ThemeMode.dark);
    await tester.pump();

    app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
