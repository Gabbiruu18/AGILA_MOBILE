  import 'package:flutter/material.dart';
  import 'package:firebase_core/firebase_core.dart';
  //import 'package:project_agila/face_registration.dart';
  import 'package:project_agila/Screens/opening.dart';
  import 'package:project_agila/Screens/login.dart';
  import 'package:project_agila/Screens/signup.dart';
  import 'package:firebase_app_check/firebase_app_check.dart';
  import 'package:permission_handler/permission_handler.dart';
  import 'package:project_agila/Screens/face_registration/face_registration.dart';
  import 'package:project_agila/Screens/face_registration/face_registration_process.dart';

  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('AIzaSyBaNdA2VaJHPh_wep9DtZjDluUzmTDzsKU'),
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    await requestPermissions();

    /*FirebaseAppCheck.instance.getToken(true).then((token) {
      print('🔥 Debug App Check token: $token');
    });*/


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
          '/facial-registration': (context) => const FacialRegistrationScreen(),
          '/registration-processing': (context) => const FacialRegistrationProcessingScreen(),


          /*'/faceRecognition': (context) => FaceRecognition(),
          '/faceRegistration': (context) => FaceRegistration()*/// Ensure this class exists
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
      Permission.storage,
      Permission.notification,
    ].request();
  }
