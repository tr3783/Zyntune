import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Small iOS helpers for video recordings (ios/Runner/AppDelegate.swift).
class DeviceFiles {
  static const _channel = MethodChannel('com.topher.zyntune/device');

  /// Keep a file out of the user's iCloud Backup (used for large videos).
  static Future<void> excludeFromBackup(String path) async {
    try {
      await _channel.invokeMethod('excludeFromBackup', path);
    } catch (e) {
      debugPrint('excludeFromBackup failed: $e');
    }
  }

  /// Free space available for the app, in bytes, or null if unknown.
  static Future<int?> freeDiskSpace() async {
    try {
      final value = await _channel.invokeMethod<num>('freeDiskSpace');
      return value?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Keep the screen from locking (while recording video).
  static Future<void> setKeepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod('setKeepScreenOn', on);
    } catch (_) {}
  }
}
