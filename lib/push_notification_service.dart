import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'notification_router.dart';

// Registers this device for push notifications. Sending happens in Cloud
// Functions (functions/src/index.ts), which hold the OneSignal REST API key.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static const String _appId = '20e7738a-bb97-4378-9f7d-5204ec5e87a3';

  bool _clickListenerAdded = false;

  Future<void> initialize() async {
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    OneSignal.initialize(_appId);

    // Tapping a notification opens the screen it's about. Register early so a
    // tap that launched the app isn't missed.
    if (!_clickListenerAdded) {
      _clickListenerAdded = true;
      OneSignal.Notifications.addClickListener((event) {
        NotificationRouter().handleTap(event.notification.additionalData);
      });
    }

    // Request permission
    await OneSignal.Notifications.requestPermission(true);

    // Tag user with their Firebase UID so we can target them
    await _tagUser();

    // Listen for subscription changes
    OneSignal.User.pushSubscription.addObserver((state) {
      _tagUser();
    });
  }

  Future<void> loginUser(String uid) async {
    try {
      await OneSignal.login(uid);
    } catch (e) {
      debugPrint('OneSignal loginUser error: $e');
    }
  }

  // Stop sending this user's notifications to this device (sign-out, account
  // deletion), so the next person to use it doesn't receive them.
  Future<void> logoutUser() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('OneSignal logoutUser error: $e');
    }
  }

  Future<void> _tagUser() async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return;
      await OneSignal.login(uid);
    } catch (e) {
      debugPrint('OneSignal tag error: $e');
    }
  }
}
