import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const int _streakReminderNotificationId = 998;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    return true;
  }

  /// Sets up the timezone helper — reused across methods
  static void _setLocalTimezone() {
    try {
      tz_data.initializeTimeZones();
      final offset = DateTime.now().timeZoneOffset;
      final offsetHours = offset.inHours;
      final String zoneName = offsetHours == -4
          ? 'America/New_York'
          : offsetHours == -5
              ? 'America/New_York'
              : offsetHours == -6
                  ? 'America/Chicago'
                  : offsetHours == -7
                      ? 'America/Denver'
                      : offsetHours == -8
                          ? 'America/Los_Angeles'
                          : offsetHours == -9
                              ? 'America/Anchorage'
                              : offsetHours == -10
                                  ? 'America/Honolulu'
                                  : 'UTC';
      tz.setLocalLocation(tz.getLocation(zoneName));
    } catch (e) {
      // fallback to UTC
    }
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      await _notifications.cancel(0);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminderHour', hour);
      await prefs.setInt('reminderMinute', minute);
      await prefs.setBool('reminderEnabled', true);

      _setLocalTimezone();

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'practice_reminder', 'Practice Reminders',
        channelDescription: 'Daily practice reminder',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.zonedSchedule(
        0,
        'Time to Practice! 🎵',
        'Your daily practice session is waiting. Keep that streak going!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      // ignore
    }
  }

  /// Schedule a daily 8pm streak-at-risk notification.
  /// Call this after every session save — it reschedules for tomorrow.
  /// Call this on app launch too so it stays active.
  static Future<void> scheduleStreakRiskReminder({required int currentStreak}) async {
    // Only bother if user has a streak worth protecting
    if (currentStreak < 1) {
      await _notifications.cancel(_streakReminderNotificationId);
      return;
    }

    try {
      await _notifications.cancel(_streakReminderNotificationId);
      _setLocalTimezone();

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0); // 8:00 PM

      // If it's already past 8pm today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final streakText = currentStreak == 1
          ? 'Your 1-day streak is at risk!'
          : 'Your $currentStreak-day streak is at risk!';

      const androidDetails = AndroidNotificationDetails(
        'streak_reminder', 'Streak Reminders',
        channelDescription: 'Daily streak at risk reminder',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.zonedSchedule(
        _streakReminderNotificationId,
        '$streakText 🔥',
        'Practice today to keep your streak going!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      // ignore
    }
  }

  /// Call after a session is saved today — cancels today's streak risk notification
  /// since the user has already practiced.
  static Future<void> cancelStreakRiskReminder() async {
    try {
      await _notifications.cancel(_streakReminderNotificationId);
    } catch (e) {
      // ignore
    }
  }

  /// Schedule a one-time notification for when the countdown finishes
  static Future<void> scheduleCountdownFinished({
    required int id,
    required int secondsFromNow,
  }) async {
    try {
      await _notifications.cancel(id);
      _setLocalTimezone();

      final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));

      const androidDetails = AndroidNotificationDetails(
        'countdown_finished', 'Countdown Timer',
        channelDescription: 'Practice countdown finished',
        importance: Importance.max,
        priority: Priority.max,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, presentBadge: true, presentSound: true,
      );
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.zonedSchedule(
        id,
        'Session Complete! 🎉',
        'Your practice countdown has finished. Great work!',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // ignore
    }
  }

  static Future<void> cancelById(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      // ignore
    }
  }

  static Future<void> cancelReminders() async {
    try {
      await _notifications.cancel(0);
    } catch (e) {
      // ignore
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminderEnabled', false);
  }

  static Future<Map<String, dynamic>> getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool('reminderEnabled') ?? false,
      'hour': prefs.getInt('reminderHour') ?? 9,
      'minute': prefs.getInt('reminderMinute') ?? 0,
    };
  }
}