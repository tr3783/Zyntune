import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'account_data_service.dart';
import 'navigation.dart';
import 'screens/studio_screen.dart';

/// Where on the home screen to bring into view.
enum HomeFocus { assignments, reminder }

/// Opens the right screen when a push notification is tapped. Notification
/// `data` comes from the Cloud Functions in functions/src/index.ts:
///   new_assignment, feedback  -> student's home screen, Assignments
///   reminder                  -> student's home screen, teacher reminder card
///   assignment_completed      -> teacher's Studio, that student's page
class NotificationRouter {
  static final NotificationRouter _instance = NotificationRouter._internal();
  factory NotificationRouter() => _instance;
  NotificationRouter._internal();

  /// HomeScreen listens and scrolls to the requested section.
  final ValueNotifier<HomeFocus?> homeFocus = ValueNotifier(null);

  Map<String, dynamic>? _pending;
  bool _routing = false;

  void handleTap(Map<String, dynamic>? data) {
    if (data == null || data['type'] == null) return;
    _pending = data;
    _route();
  }

  Future<void> _route({int attempt = 0}) async {
    if (_routing) return;
    _routing = true;
    try {
      final data = _pending;
      if (data == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _pending = null;
        return;
      }
      // Wait until the account's data is loaded and the app is showing.
      await AccountDataService().ensureReady(uid);
      final nav = navigatorKey.currentState;
      if (nav == null) {
        // Cold start: the app isn't built yet. Try again shortly.
        if (attempt < 20) {
          _routing = false;
          Future.delayed(const Duration(milliseconds: 250), () => _route(attempt: attempt + 1));
        }
        return;
      }
      _pending = null;
      nav.popUntil((route) => route.isFirst);

      switch (data['type']) {
        case 'new_assignment':
        case 'feedback':
          homeFocus.value = HomeFocus.assignments;
        case 'reminder':
          homeFocus.value = HomeFocus.reminder;
        case 'assignment_completed':
          await _openStudent(nav, uid, data['studentUid'] as String?);
      }
    } catch (e) {
      debugPrint('NotificationRouter: $e');
    } finally {
      _routing = false;
    }
  }

  Future<void> _openStudent(NavigatorState nav, String teacherUid, String? studentUid) async {
    nav.push(MaterialPageRoute(builder: (_) => const StudioScreen()));
    if (studentUid == null || studentUid.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(studentUid).get();
    final data = doc.data();
    // Only the student's own teacher (e.g. not someone else on a shared device).
    if (data == null || data['teacherId'] != teacherUid) return;
    nav.push(MaterialPageRoute(builder: (_) => StudentDetailScreen(studentUid: studentUid, studentData: data)));
  }
}
