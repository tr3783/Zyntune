import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'notification_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('darkMode') ?? true;
  final onboardingComplete =
      prefs.getBool('onboardingComplete') ?? false;

  // Initialize notifications
  await NotificationHelper.initialize();

  runApp(PracticePilotApp(
    isDarkMode: isDarkMode,
    onboardingComplete: onboardingComplete,
  ));
}

class PracticePilotApp extends StatefulWidget {
  final bool isDarkMode;
  final bool onboardingComplete;

  const PracticePilotApp({
    super.key,
    required this.isDarkMode,
    required this.onboardingComplete,
  });

  static _PracticePilotAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_PracticePilotAppState>();

  @override
  State<PracticePilotApp> createState() => _PracticePilotAppState();
}

class _PracticePilotAppState extends State<PracticePilotApp> {
  late bool _isDarkMode;
  late bool _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _onboardingComplete = widget.onboardingComplete;
  }

  void toggleTheme() async {
    setState(() => _isDarkMode = !_isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Practice Pilot',
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
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: _onboardingComplete
          ? const HomeScreen()
          : const OnboardingScreen(),
    );
  }
}