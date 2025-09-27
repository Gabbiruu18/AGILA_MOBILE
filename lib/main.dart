import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:permission_handler/permission_handler.dart';
// Keep this import only if you use prefs elsewhere in main.dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:project_agila/Screens/Face Recognition/face_recognition_tester.dart';
import 'package:project_agila/Screens/MainScreens/opening.dart';
import 'package:project_agila/Screens/MainScreens/login.dart';
import 'package:project_agila/Screens/face_registration/face_registration.dart';
import 'package:project_agila/Screens/face_registration/face_registration_process.dart';
import 'package:project_agila/Screens/MainScreens/quick_login.dart';
import 'package:project_agila/Screens/UI_Screen/home.dart';

// NEW: theme wiring
import 'package:project_agila/Screens/Theme/agila_theme.dart';
import 'package:project_agila/Screens/Theme/theme_controller.dart';
import 'package:project_agila/Screens/Theme/theme_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('AIzaSyBaNdA2VaJHPh_wep9DtZjDluUzmTDzsKU'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  await requestPermissions();

  // === THEME CONTROLLER: load persisted mode before runApp ===
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
          // THEME HOOKS
          theme: agilaLight,
          darkTheme: agilaDark,
          themeMode: themeCtrl.mode,

          initialRoute: '/opening', // Always go to Opening first
          routes: {
            '/opening': (context) => const OpeningScreen(),
            '/': (context) => const LoginScreen(),
            '/quick-login': (context) => const QuickLoginScreen(),
            '/facial-registration': (context) => const FacialRegistrationScreen(),
            '/registration-processing': (context) => const FacialRegistrationProcessingScreen(),
            '/face-recognition-tester': (context) => const FaceRecognitionTesterScreen(),

            '/home': (context) {
              final args = ModalRoute.of(context)!.settings.arguments as Map;
              return HomeScreen(
                role: args['role'],
                name: args['name'],
                uid: args['uid'],
                firstName: args['firstName'],
                lastName: args['lastName'],
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
