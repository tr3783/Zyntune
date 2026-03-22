import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    // Permission is requested automatically on iOS
    // via DarwinInitializationSettings above
    return true;
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      await _notifications.cancelAll();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminderHour', hour);
      await prefs.setInt('reminderMinute', minute);
      await prefs.setBool('reminderEnabled', true);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate =
            scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'practice_reminder',
        'Practice Reminders',
        channelDescription: 'Daily practice reminder',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        0,
        'Time to Practice!',
        'Your daily practice session is waiting. Keep that streak going!',
        scheduledDate,
        details,
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation
                .absoluteTime,
        matchDateTimeComponents:
            DateTimeComponents.time,
      );
    } catch (e) {
      // Handle silently
    }
  }

  static Future<void> cancelReminders() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      // Handle silently
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminderEnabled', false);
  }

  static Future<Map<String, dynamic>> getReminderSettings()
      async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool('reminderEnabled') ?? false,
      'hour': prefs.getInt('reminderHour') ?? 9,
      'minute': prefs.getInt('reminderMinute') ?? 0,
    };
  }
}