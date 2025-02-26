import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:project_agila/opening.dart';
import 'package:project_agila/login.dart';
import 'package:project_agila/signup.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('AIzaSyBaNdA2VaJHPh_wep9DtZjDluUzmTDzsKU'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  await requestPermissions();

  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/opening',
      routes: {
        '/opening': (context) => const OpeningScreen(),
        '/': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
      },
    );
  }
}

Future<void> requestPermissions() async {
  await [
    Permission.camera,
    Permission.storage,
    Permission.photos,
  ].request();
}
