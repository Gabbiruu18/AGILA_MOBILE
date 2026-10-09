import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:project_agila/Screens/MainScreens/opening.dart';
import 'package:project_agila/Screens/MainScreens/login.dart';
import 'package:project_agila/Screens/MainScreens/quick_login.dart';
import 'package:project_agila/Service_Modules/Home/home.dart';
import 'package:project_agila/Screens/Theme/agila_theme.dart';
import 'package:project_agila/Screens/Theme/theme_controller.dart';
import 'package:project_agila/Screens/Theme/theme_scope.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Service_Modules/Notification/notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> setupForegroundNotifications() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

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
            icon: 'launch_background',
          ),
        ),
      );
    }
  });
}
class FCMTokenManager {
  static Future<void> cleanupTokenIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      final uid = prefs.getString('rememberedUid');

      if (!rememberMe && uid != null) {
        await _cleanupFCMToken(uid);
      }
    } catch (e) {
      debugPrint('Error in FCM token cleanup: $e');
    }
  }

  static Future<void> _cleanupFCMToken(String uid) async {
    try {
      const roles = ['student', 'teacher', 'program_head'];
      for (final role in roles) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(role)
            .collection('accounts')
            .doc(uid);

        final doc = await docRef.get();
        if (doc.exists) {
          await docRef.update({
            'fcmToken': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('FCM token deleted for user: $uid in role: $role');
          break;
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up FCM token: $e');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupForegroundNotifications();

  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('AIzaSyBaNdA2VaJHPh_wep9DtZjDluUzmTDzsKU'),
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  await NotificationService().init();
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

class MyApp extends StatefulWidget {
  final ThemeController themeCtrl;
  const MyApp({super.key, required this.themeCtrl});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      FCMTokenManager.cleanupTokenIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeCtrl,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: agilaLight,
          darkTheme: agilaDark,
          themeMode: widget.themeCtrl.mode,
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