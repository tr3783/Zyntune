import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'notification_helper.dart';
import 'metronome_service.dart';
import 'timer_service.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

void _showGlobalCountdownDialog() {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Time\'s Up! ⏰'),
      content: const Text(
          'Your practice session is complete! Great work!'),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            TimerService().resetCountdown();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Done!'),
        ),
      ],
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('darkMode') ?? true;
  final onboardingComplete =
      prefs.getBool('onboardingComplete') ?? false;

  MetronomeService();
  TimerService().onCountdownFinished =
      _showGlobalCountdownDialog;

  await NotificationHelper.initialize();
  runApp(ZyntuneApp(
    isDarkMode: isDarkMode,
    onboardingComplete: onboardingComplete,
  ));
}

class ZyntuneApp extends StatefulWidget {
  final bool isDarkMode;
  final bool onboardingComplete;
  const ZyntuneApp({
    super.key,
    required this.isDarkMode,
    required this.onboardingComplete,
  });

  static _ZyntuneAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ZyntuneAppState>();

  @override
  State<ZyntuneApp> createState() => _ZyntuneAppState();
}

class _ZyntuneAppState extends State<ZyntuneApp>
    with WidgetsBindingObserver {
  late bool _isDarkMode;
  late bool _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _onboardingComplete = widget.onboardingComplete;
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
    }
  }

  void toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zyntune',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: _onboardingComplete
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}