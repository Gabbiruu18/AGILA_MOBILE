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

// --- ADDED: Import the necessary notification packages ---
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ---------------------------------------------------------

// --- ADDED: Create an instance of the local notifications plugin ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
// -----------------------------------------------------------------

// --- ADDED: This function sets up everything for foreground notifications ---
Future<void> setupForegroundNotifications() async {
  // 1. Create a Notification Channel for Android (required for Android 8.0+)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // A unique ID for the channel
    'High Importance Notifications', // A user-visible name for the channel
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  // 2. Initialize the local notifications plugin
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 3. Set up the listener for incoming foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // If the message has a notification payload, show it as a local notification
    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            // IMPORTANT: 'launch_background' must be a file in android/app/src/main/res/drawable
            icon: 'launch_background',
          ),
        ),
      );
    }
  });
}
// -------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // --- ADDED: Call the setup function when the app starts ---
  await setupForegroundNotifications();
  // -------------------------------------------------------

  // --- 2. SECURITY NOTE FOR PRODUCTION ---
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('AIzaSyBaNdA2VaJHPh_wep9DtZjDluUzmTDzsKU'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

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
            '/home': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args == null || args is! Map) {
                debugPrint("Error: /home route was pushed without valid arguments. Redirecting to login.");
                return const LoginScreen();
              }
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