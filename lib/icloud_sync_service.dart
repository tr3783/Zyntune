import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Syncs device settings across the user's Apple devices via iCloud.
///
/// iCloud belongs to whoever owns the device, not to whoever is signed in to
/// Zyntune, so personal data (practice history, repertoire, notes...) is NOT
/// synced here — it's backed up to the Zyntune account by AccountDataService.
/// Older versions stored personal data in iCloud too; pulls ignore it.
class ICloudSyncService {
  static const _channel = MethodChannel('com.topher.zyntune/icloud');

  static const _keys = [
    'darkMode',
    'reminderEnabled',
    'reminderHour',
    'reminderMinute',
    'sharePromptEnabled',
    'isProUser',
    'isGrandfathered',
    'grandfatherChecked',
  ];

  /// Push device settings to iCloud
  static Future<void> pushToICloud() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {};

      for (final key in _keys) {
        final value = prefs.get(key);
        if (value != null) {
          data[key] = value;
        }
      }

      await _channel.invokeMethod('setValues', {'data': jsonEncode(data)});
    } catch (e) {
      // iCloud not available — fail silently
    }
  }

  /// Pull device settings from iCloud into local SharedPreferences
  static Future<void> pullFromICloud() async {
    try {
      final result = await _channel.invokeMethod('getValues');
      if (result == null) return;

      final Map<String, dynamic> data = jsonDecode(result as String);
      final prefs = await SharedPreferences.getInstance();

      for (final key in _keys) {
        final value = data[key];
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        }
      }
    } catch (e) {
      // iCloud not available — fail silently
    }
  }

  /// Call after any settings save to keep iCloud in sync
  static Future<void> sync() async {
    await pushToICloud();
  }

  /// Call on app launch to pull latest from iCloud
  static Future<void> syncOnLaunch() async {
    await pullFromICloud();
  }
}
