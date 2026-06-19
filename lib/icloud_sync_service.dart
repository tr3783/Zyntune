import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ICloudSyncService {
  static const _channel = MethodChannel('com.topher.zyntune/icloud');

  static const _keys = [
    'practiceSessions',
    'songs',
    'currentStreak',
    'longestStreak',
    'lastPracticeDate',
    'practicePoints',
    'streakFreezeActive',
    'streakFreezeUsedDate',
    'userName',
    'instruments',
    'activeInstrument',
    'dailyGoalMinutes',
    'achievements',
    'notes',
    'darkMode',
    'reminderEnabled',
    'reminderHour',
    'reminderMinute',
    'sharePromptEnabled',
    'isProUser',
    'isGrandfathered',
    'grandfatherChecked',
  ];

  /// Push all local SharedPreferences data to iCloud
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

  /// Pull iCloud data and merge into local SharedPreferences
  static Future<void> pullFromICloud() async {
    try {
      final result = await _channel.invokeMethod('getValues');
      if (result == null) return;

      final Map<String, dynamic> data = jsonDecode(result as String);
      final prefs = await SharedPreferences.getInstance();

      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value == null) continue;

        if (key == 'practiceSessions' || key == 'songs' || key == 'instruments') {
          // Merge lists — union of local and remote, deduplicated by id/title
          if (value is List) {
            final remoteList = List<String>.from(value.map((e) => e.toString()));
            final localList = prefs.getStringList(key) ?? [];
            final merged = _mergeLists(key, localList, remoteList);
            await prefs.setStringList(key, merged);
          }
        } else if (value is String) {
          // Only overwrite if remote value is newer/larger for streak data
          if (key == 'currentStreak' || key == 'longestStreak' || key == 'practicePoints') {
            final localVal = prefs.getInt(key) ?? 0;
            final remoteVal = int.tryParse(value) ?? 0;
            if (remoteVal > localVal) await prefs.setInt(key, remoteVal);
          } else {
            await prefs.setString(key, value);
          }
        } else if (value is int) {
          if (key == 'currentStreak' || key == 'longestStreak' || key == 'practicePoints') {
            final localVal = prefs.getInt(key) ?? 0;
            if (value > localVal) await prefs.setInt(key, value);
          } else {
            await prefs.setInt(key, value);
          }
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        }
      }
    } catch (e) {
      // iCloud not available — fail silently
    }
  }

  /// Merge two lists of JSON strings, deduplicating by 'id' for sessions
  /// and by 'title' for songs
  static List<String> _mergeLists(String key, List<String> local, List<String> remote) {
    if (key == 'instruments') {
      // Simple union for instruments
      final combined = {...local, ...remote}.toList();
      return combined;
    }

    final String idField = key == 'practiceSessions' ? 'id' : 'title';
    final Map<String, String> merged = {};

    // Add local first
    for (final item in local) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        final id = map[idField]?.toString() ?? '';
        if (id.isNotEmpty) merged[id] = item;
      } catch (_) {}
    }

    // Add remote (overwrites local if same id — remote wins for conflicts)
    for (final item in remote) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        final id = map[idField]?.toString() ?? '';
        if (id.isNotEmpty) merged[id] = item;
      } catch (_) {}
    }

    // Sort sessions by date descending
    final result = merged.values.toList();
    if (key == 'practiceSessions') {
      result.sort((a, b) {
        try {
          final aDate = (jsonDecode(a) as Map)['date'] as String;
          final bDate = (jsonDecode(b) as Map)['date'] as String;
          return bDate.compareTo(aDate);
        } catch (_) {
          return 0;
        }
      });
    }

    return result;
  }

  /// Call after any data save to keep iCloud in sync
  static Future<void> sync() async {
    await pushToICloud();
  }

  /// Call on app launch to pull latest from iCloud
  static Future<void> syncOnLaunch() async {
    await pullFromICloud();
  }
}