import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/theme_service.dart';
import 'services/push_notification_service.dart';
import 'services/notification_scheduler_service.dart';

// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase and push notifications
  await _initializeFirebase();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SuvidhaConnectApp());
}

// Initialize Firebase
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    // Initialize push notifications
    await PushNotificationService.initialize();
    // Initialize notification scheduler
    await NotificationSchedulerService.initialize();
    print('✅ Firebase and push notifications initialized');
  } catch (e) {
    print('⚠️ Firebase initialization failed: $e');
    print('   Make sure google-services.json is in android/app/');
    print('   And GoogleService-Info.plist is in ios/Runner/');
  }
}

class SuvidhaConnectApp extends StatefulWidget {
  const SuvidhaConnectApp({super.key});

  @override
  State<SuvidhaConnectApp> createState() => _SuvidhaConnectAppState();
}

class _SuvidhaConnectAppState extends State<SuvidhaConnectApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, themeMode, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            final canPop = appRootNavigatorKey.currentState?.canPop() ?? false;
            if (canPop) {
              appRouter.pop();
            } else {
              _showExitConfirmation();
            }
          },
          child: MaterialApp.router(
            title: 'Suvidha',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: appRouter,
          ),
        );
      },
    );
  }

  void _showExitConfirmation() {
    final context = appRootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit app?'),
        content: const Text('Do you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              SystemNavigator.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
