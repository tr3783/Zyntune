import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static const String _appId = '20e7738a-bb97-4378-9f7d-5204ec5e87a3';
  String? _restApiKey;

  Future<void> initialize() async {
    OneSignal.Debug.setLogLevel(OSLogLevel.warn);
    OneSignal.initialize(_appId);

    // Request permission
    await OneSignal.Notifications.requestPermission(true);

    // Tag user with their Firebase UID so we can target them
    await _tagUser();

    // Load REST API key from Firestore
    await _loadApiKey();

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

  Future<void> _tagUser() async {
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return;
      await OneSignal.login(uid);
    } catch (e) {
      debugPrint('OneSignal tag error: $e');
    }
  }

  Future<void> _loadApiKey() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('onesignal')
          .get();
      _restApiKey = doc.data()?['restApiKey'] as String?;
    } catch (e) {
      debugPrint('Error loading OneSignal API key: $e');
    }
  }

  Future<void> _sendNotification({
    required String targetUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (_restApiKey == null) await _loadApiKey();
      if (_restApiKey == null) return;

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'target_channel': 'push',
          'include_aliases': {'external_id': [targetUid]},
          'headings': {'en': title},
          'contents': {'en': body},
          'data': data ?? {},
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('OneSignal error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> notifyNewAssignment({
    required String studentUid,
    required String assignmentTitle,
    required String teacherName,
  }) async {
    await _sendNotification(
      targetUid: studentUid,
      title: '📋 New Assignment from $teacherName',
      body: assignmentTitle,
      data: {'type': 'new_assignment'},
    );
  }

  Future<void> notifyAssignmentCompleted({
    required String teacherUid,
    required String studentName,
    required String assignmentTitle,
  }) async {
    await _sendNotification(
      targetUid: teacherUid,
      title: '✅ $studentName completed an assignment',
      body: assignmentTitle,
      data: {'type': 'assignment_completed'},
    );
  }

  Future<void> notifyFeedbackReceived({
    required String studentUid,
    required String teacherName,
    required String assignmentTitle,
  }) async {
    await _sendNotification(
      targetUid: studentUid,
      title: '💬 Feedback from $teacherName',
      body: 'New feedback on: $assignmentTitle',
      data: {'type': 'feedback'},
    );
  }

  Future<void> notifyReminder({
    required String studentUid,
    required String teacherName,
    String? message,
  }) async {
    await _sendNotification(
      targetUid: studentUid,
      title: '👋 Reminder from $teacherName',
      body: message?.trim().isNotEmpty == true ? message!.trim() : "Don't forget to practice today!",
      data: {'type': 'reminder'},
    );
  }
}