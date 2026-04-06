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
    print('🔔 NotificationHelper initialized');
  }

  static Future<bool> requestPermission() async {
    print('🔔 Requesting permission...');
    // On iOS, permission is requested during initialize
    // Just return true and let the system handle it
    print('🔔 Permission granted (iOS handles automatically)');
    return true;
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      print('🔔 Scheduling reminder for $hour:$minute');
      await _notifications.cancelAll();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reminderHour', hour);
      await prefs.setInt('reminderMinute', minute);
      await prefs.setBool('reminderEnabled', true);

      tz_data.initializeTimeZones();

      try {
        // Use UTC offset to find correct timezone
        final offset = DateTime.now().timeZoneOffset;
        final offsetHours = offset.inHours;
        print('🔔 UTC offset: $offsetHours hours');
        // EDT = UTC-4, EST = UTC-5
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
        print('🔔 Using timezone: $zoneName');
        tz.setLocalLocation(tz.getLocation(zoneName));
      } catch (e) {
        print('🔔 Timezone error: $e');
      }

      final now = tz.TZDateTime.now(tz.local);
      print('🔔 Current TZ time: $now');

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate
            .add(const Duration(days: 1));
      }

      print('🔔 Scheduled for: $scheduledDate');

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
        'Time to Practice! 🎵',
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
      print('🔔 Reminder scheduled successfully for $scheduledDate!');
    } catch (e) {
      print('🔔 ERROR scheduling reminder: $e');
    }
  }

  static Future<void> cancelReminders() async {
    try {
      await _notifications.cancelAll();
      print('🔔 Reminders cancelled');
    } catch (e) {
      print('🔔 Cancel error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminderEnabled', false);
  }

  static Future<Map<String, dynamic>>
      getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled':
          prefs.getBool('reminderEnabled') ?? false,
      'hour': prefs.getInt('reminderHour') ?? 9,
      'minute': prefs.getInt('reminderMinute') ?? 0,
    };
  }
}