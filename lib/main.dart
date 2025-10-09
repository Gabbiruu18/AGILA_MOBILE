import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:project_agila/Screens/MainScreens/opening.dart';
import 'package:project_agila/Screens/MainScreens/login.dart';
import 'package:project_agila/Screens/MainScreens/quick_login.dart';
import 'package:project_agila/Screens/UI_Screen/home.dart';

import 'package:project_agila/Screens/Theme/agila_theme.dart';
import 'package:project_agila/Screens/Theme/theme_controller.dart';
import 'package:project_agila/Screens/Theme/theme_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // --- 2. SECURITY NOTE FOR PRODUCTION ---
  // Before releasing your app, you MUST replace the .debug providers
  // with the production providers (e.g., AndroidProvider.playIntegrity).
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('AIzaSyBaNdA2VaJHPh_wep9DtZjDluUzmTDzsKU'), // Replace with your actual key
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // Consider moving permission requests to be "just-in-time" (when they are needed)
  // instead of requesting them all on startup.
  await requestPermissions();

  final themeCtrl = ThemeController();
  await themeCtrl.load();

  runApp(
    ThemeScope(
      controller: themeCtrl,
      child: MyApp(themeCtrl: themeCtrl),
    ),
  );
}

class MyApp extends StatelessWidget {
  final ThemeController themeCtrl;
  const MyApp({super.key, required this.themeCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeCtrl,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: agilaLight,
          darkTheme: agilaDark,
          themeMode: themeCtrl.mode,
          initialRoute: '/opening',
          routes: {
            '/opening': (context) => const OpeningScreen(),
            '/': (context) => const LoginScreen(),
            '/quick-login': (context) => const QuickLoginScreen(),
            //'/face-recognition-tester': (context) => const FaceRecognitionTesterScreen(),

            // --- 1. CRASH-PROOF NAVIGATION ---
            '/home': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;

              // Defensive check: If arguments are missing or not a Map,
              // gracefully redirect to the login screen to prevent a crash.
              if (args == null || args is! Map) {
                debugPrint("Error: /home route was pushed without valid arguments. Redirecting to login.");
                return const LoginScreen();
              }

              // Safely access arguments with default values to prevent null errors.
              return HomeScreen(
                role: args['role'] ?? 'default_role',
                name: args['name'] ?? 'Unknown User',
                uid: args['uid'] ?? '',
                firstName: args['firstName'] ?? '',
                lastName: args['lastName'] ?? '',
              );
            },
          },
        );
      },
    );
  }
}

Future<void> requestPermissions() async {
  await [
    Permission.camera,
    Permission.storage,
    Permission.photos,
    Permission.location,
    Permission.notification,
  ].request();
}