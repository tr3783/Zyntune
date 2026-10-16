import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_helper.dart';
import 'metronome_service.dart';
import 'timer_service.dart';
import 'purchase_service.dart';
import 'icloud_sync_service.dart';
import 'streak_helper.dart';
import 'widget_service.dart';
import 'firebase_options.dart';
import 'push_notification_service.dart';
import 'auth_gate.dart';
import 'navigation.dart';
import 'screens/timer_screen.dart';
import 'account_data_service.dart';


Future<void> _showGlobalCountdownDialog() async {
  // Signed out: keep the finished countdown; the timer screen offers to save
  // it after sign-in.
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  // On launch, wait until the account's data is loaded before saving into it.
  await AccountDataService().ensureReady(user.uid);
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Time\'s Up! ⏰'),
      content: const Text('Your practice session is complete! Great work! Save it to your practice history?'),
      actions: [
        // "Later" keeps the finished countdown, so the timer screen offers
        // to save it when opened.
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // The timer screen shows its save dialog for a finished countdown.
            navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const TimerScreen()));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: const Text('Save Session'),
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

  // Data saved before 2.5.1 didn't record which account it belonged to.
  await AccountDataService().migrateLegacyData(FirebaseAuth.instance.currentUser?.uid);

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
    // Only schedule if user hasn't practiced today
    final todayStr = DateTime.now().toString().substring(0, 10);
    final sessions = prefs.getStringList('practiceSessions') ?? [];
    final practicedToday = sessions.any((s) => s.contains(todayStr));
    if (!practicedToday) {
      final streakData = await StreakHelper.getStreakData();
      await NotificationHelper.scheduleStreakRiskReminder(
        currentStreak: streakData['currentStreak'] ?? 0,
      );
    } else {
      await NotificationHelper.cancelStreakRiskReminder();
    }
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
    // A countdown may have finished while iOS had closed the app.
    WidgetsBinding.instance.addPostFrameCallback((_) => TimerService().syncOnResume());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // The metronome keeps playing in the background (screen locked, other apps).
      ICloudSyncService.sync();
      AccountDataService().sync();
    }
    if (state == AppLifecycleState.resumed) {
      TimerService().syncOnResume();
      ICloudSyncService.syncOnLaunch();
      AccountDataService().sync();
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
      home: const AuthGate(),
    );
  }
}