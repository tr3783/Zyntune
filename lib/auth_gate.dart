import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'push_notification_service.dart';

// Root of the app: shows login, onboarding or home based on sign-in state.
// It must stay at the root of the navigator so that signing out or deleting
// the account returns to the login screen. Don't replace it with pushReplacement.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
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
    );
  }
}
