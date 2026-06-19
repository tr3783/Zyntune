import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'notification_helper.dart';
import 'metronome_service.dart';
import 'timer_service.dart';
import 'purchase_service.dart';
import 'icloud_sync_service.dart';
import 'streak_helper.dart';
import 'widget_service.dart';
import 'firebase_options.dart';
import 'push_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _showGlobalCountdownDialog() {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Time\'s Up! ⏰'),
      content: const Text('Your practice session is complete! Great work!'),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            TimerService().resetCountdown();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: const Text('Done!'),
        ),
      ],
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await PurchaseService.grandfatherExistingUsers();

  MetronomeService();
  TimerService().onCountdownFinished = _showGlobalCountdownDialog;
  await NotificationHelper.initialize();

  final purchaseService = PurchaseService();
  await purchaseService.initialize();

  await WidgetService.updateWidget();
  await ICloudSyncService.syncOnLaunch();

  // Initialize push notifications if user is logged in
  if (FirebaseAuth.instance.currentUser != null) {
    await PushNotificationService().initialize();
  }

  final prefs = await SharedPreferences.getInstance();
  final streakReminderEnabled = prefs.getBool('streakReminderEnabled') ?? true;
  if (streakReminderEnabled) {
    final streakData = await StreakHelper.getStreakData();
    await NotificationHelper.scheduleStreakRiskReminder(
      currentStreak: streakData['currentStreak'] ?? 0,
    );
  }

  runApp(const ZyntuneApp());
}

class ZyntuneApp extends StatefulWidget {
  const ZyntuneApp({super.key});

  static _ZyntuneAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ZyntuneAppState>();

  @override
  State<ZyntuneApp> createState() => _ZyntuneAppState();
}

class _ZyntuneAppState extends State<ZyntuneApp> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused) {
      MetronomeService().stop();
      ICloudSyncService.sync();
    }
    if (state == AppLifecycleState.resumed) {
      ICloudSyncService.syncOnLaunch();
      WidgetService.updateWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zyntune',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0D0D1A),
              body: Center(child: CircularProgressIndicator(color: Color(0xFF6B21FF))),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginScreen();
          }

          // Initialize push notifications for logged in user (once only)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            PushNotificationService().initialize();
          });

          return FutureBuilder<bool>(
            future: SharedPreferences.getInstance()
                .then((p) => p.getBool('onboardingComplete') ?? false),
            builder: (context, onboardingSnap) {
              if (!onboardingSnap.hasData) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0D0D1A),
                  body: Center(child: CircularProgressIndicator(color: Color(0xFF6B21FF))),
                );
              }
              if (!onboardingSnap.data!) {
                return const OnboardingScreen();
              }
              return const HomeScreen();
            },
          );
        },
      ),
    );
  }
}