import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => AuthService().currentUser?.uid;

  // ─────────────────────────────────────────
  // SESSIONS
  // ─────────────────────────────────────────

  Future<void> saveSession(Map<String, dynamic> session) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final sessionId = session['id'] as String;
      await _db.collection('users').doc(uid).collection('sessions').doc(sessionId).set({
        ...session,
        'savedAt': FieldValue.serverTimestamp(),
      });
      await _updateUserStats(uid);
    } catch (_) {}
  }

  Future<void> deleteSession(String sessionId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).collection('sessions').doc(sessionId).delete();
      await _updateUserStats(uid);
    } catch (_) {}
  }

  Future<void> updateSession(Map<String, dynamic> session) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final sessionId = session['id'] as String;
      await _db.collection('users').doc(uid).collection('sessions').doc(sessionId).update(session);
      await _updateUserStats(uid);
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> getStudentSessions(String studentUid) {
    return _db.collection('users').doc(studentUid).collection('sessions')
        .orderBy('date', descending: true).limit(30).snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  
  // ─────────────────────────────────────────
  // USER STATS
  // ─────────────────────────────────────────

  Future<void> _updateUserStats(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = prefs.getStringList('practiceSessions') ?? [];
      final streak = prefs.getInt('currentStreak') ?? 0;
      final longestStreak = prefs.getInt('longestStreak') ?? 0;
      final totalMinutes = sessions.fold<int>(0, (sum, s) {
        try {
          final map = jsonDecode(s) as Map<String, dynamic>;
          return sum + (map['durationMinutes'] as int? ?? 0);
        } catch (_) { return sum; }
      });
      await _db.collection('users').doc(uid).update({
        'currentStreak': streak,
        'longestStreak': longestStreak,
        'totalSessions': sessions.length,
        'totalMinutes': totalMinutes,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> updateStreak(int currentStreak, int longestStreak) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      });
    } catch (_) {}
  }

  // ─────────────────────────────────────────
  // ASSIGNMENTS
  // ─────────────────────────────────────────

  /// Teacher creates a multi-piece assignment for a student
  Future<String?> createAssignmentV2({
    required String studentUid,
    required String title,
    required String notes,
    required List<Map<String, dynamic>> pieces,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = _db.collection('users').doc(studentUid).collection('assignments').doc();
      final allItems = pieces.expand((p) => (p['checklistItems'] as List<dynamic>? ?? [])).toList();
      await ref.set({
        'id': ref.id,
        'teacherUid': uid,
        'studentUid': studentUid,
        'title': title,
        'notes': notes,
        'piece': pieces.isNotEmpty ? pieces[0]['piece'] : '',
        'pieces': pieces,
        'checklistItems': allItems,
        'completed': false,
        'seenByStudent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Cloud Function notifies the student and CCs the parent
      try {
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        await functions.httpsCallable('notifyNewAssignment').call({
          'studentUid': studentUid,
          'assignmentTitle': title,
        });
      } catch (_) {}

      return ref.id;
    } catch (_) { return null; }
  }

  /// Teacher creates an assignment (legacy)
  Future<String?> createAssignment({
    required String studentUid,
    required String title,
    required String piece,
    required String notes,
    required List<String> checklistItems,
  }) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = _db.collection('users').doc(studentUid).collection('assignments').doc();
      await ref.set({
        'id': ref.id,
        'teacherUid': uid,
        'studentUid': studentUid,
        'title': title,
        'piece': piece,
        'notes': notes,
        'checklistItems': checklistItems.map((text) => {
          'id': DateTime.now().millisecondsSinceEpoch.toString() + text.hashCode.toString(),
          'text': text,
          'checked': false,
        }).toList(),
        'completed': false,
        'seenByStudent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (_) { return null; }
  }

  /// Student view — all assignments
  Stream<List<Map<String, dynamic>>> getMyAssignments() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).collection('assignments')
        .orderBy('createdAt', descending: true).snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Teacher view — student assignments
  Stream<List<Map<String, dynamic>>> getStudentAssignments(String studentUid) {
    return _db.collection('users').doc(studentUid).collection('assignments')
        .orderBy('createdAt', descending: true).snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// Student updates assignment
  Future<void> updateAssignment(String assignmentId, Map<String, dynamic> updates) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).collection('assignments').doc(assignmentId).update(updates);

      // If marking complete, the Cloud Function notifies the teacher
      if (updates['completed'] == true) {
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
        await functions.httpsCallable('notifyAssignmentCompleted').call({'assignmentId': assignmentId});
      }
    } catch (_) {}
  }

  /// Mark assignment as seen by student
  Future<void> markAssignmentSeen(String assignmentId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).collection('assignments').doc(assignmentId).update({'seenByStudent': true});
    } catch (_) {}
  }

  /// Count unseen assignments for student (for badge)
  Stream<int> getUnseenAssignmentCount() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).collection('assignments')
        .where('seenByStudent', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Count completed assignments for teacher (new completions they haven't seen)
  Stream<int> getNewCompletionsCount(String teacherUid) {
    return _db.collectionGroup('assignments')
        .where('teacherUid', isEqualTo: teacherUid)
        .where('completed', isEqualTo: true)
        .where('seenByTeacher', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Teacher deletes an assignment
  Future<void> deleteAssignment(String studentUid, String assignmentId) async {
    try {
      await _db.collection('users').doc(studentUid).collection('assignments').doc(assignmentId).delete();
    } catch (_) {}
  }

  // ─────────────────────────────────────────
  // TEACHER FEEDBACK
  // ─────────────────────────────────────────

  /// Teacher adds feedback to an assignment
  Future<void> addFeedback({
    required String studentUid,
    required String assignmentId,
    required String feedback,
  }) async {
    try {
      await _db.collection('users').doc(studentUid).collection('assignments').doc(assignmentId).update({
        'teacherFeedback': feedback,
        'feedbackAt': FieldValue.serverTimestamp(),
        'feedbackSeenByStudent': false,
        'seenByTeacher': true,
      });

      // Cloud Function notifies the student
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions.httpsCallable('notifyFeedbackReceived').call({
        'studentUid': studentUid,
        'assignmentId': assignmentId,
      });
    } catch (_) {}
  }

  /// Student marks feedback as seen
  Future<void> markFeedbackSeen(String assignmentId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).collection('assignments').doc(assignmentId).update({'feedbackSeenByStudent': true});
    } catch (_) {}
  }

  /// Count unseen feedback for student
  Stream<int> getUnseenFeedbackCount() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').doc(uid).collection('assignments')
        .where('feedbackSeenByStudent', isEqualTo: false)
        .where('teacherFeedback', isNull: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ─────────────────────────────────────────
  // GOALS & NOTES SYNC
  // ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchGoals() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return [];
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return (doc.data()?['goals'] as List<dynamic>? ?? []).map((g) => Map<String, dynamic>.from(g as Map)).toList();
    } catch (_) { return []; }
  }

  Future<List<Map<String, dynamic>>> fetchLessonNotes() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return [];
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return (doc.data()?['lessonNotes'] as List<dynamic>? ?? []).map((n) => Map<String, dynamic>.from(n as Map)).toList();
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>?> getStudentProfile(String studentUid) async {
    try {
      final doc = await _db.collection('users').doc(studentUid).get();
      return doc.data();
    } catch (_) { return null; }
  }
}