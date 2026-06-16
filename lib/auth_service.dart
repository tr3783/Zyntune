import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'push_notification_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // --- Email/Password Sign Up ---
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String instrument,
    required String role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      await _createUserProfile(
        uid: credential.user!.uid,
        email: email,
        name: name,
        instrument: instrument,
        role: role,
      );
      await _syncLocalDataToFirestore(credential.user!.uid);
      await PushNotificationService().loginUser(credential.user!.uid);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _authError(e);
    }
  }

  // --- Email/Password Sign In ---
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _syncLocalDataToFirestore(credential.user!.uid);
      await PushNotificationService().loginUser(credential.user!.uid);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _authError(e);
    }
  }

  // --- Create user profile in Firestore ---
  Future<void> _createUserProfile({
    required String uid,
    required String email,
    required String name,
    required String instrument,
    required String role,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,
      'instrument': instrument,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'isPro': false,
      'currentStreak': 0,
      'longestStreak': 0,
      'totalSessions': 0,
      'totalMinutes': 0,
    });
  }

  // --- Sync local SharedPreferences data to Firestore ---
  Future<void> _syncLocalDataToFirestore(String uid) async {
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

      // Update user stats
      await _db.collection('users').doc(uid).update({
        'currentStreak': streak,
        'longestStreak': longestStreak,
        'totalSessions': sessions.length,
        'totalMinutes': totalMinutes,
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });

      // Sync individual sessions to subcollection
      if (sessions.isNotEmpty) {
        final batch = _db.batch();
        for (final s in sessions) {
          try {
            final session = jsonDecode(s) as Map<String, dynamic>;
            final sessionId = session['id'] as String;
            final ref = _db
                .collection('users')
                .doc(uid)
                .collection('sessions')
                .doc(sessionId);
            batch.set(ref, {
              ...session,
              'savedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}
        }
        await batch.commit();
      }

      // Sync repertoire
      final songs = prefs.getStringList('songs') ?? [];
      if (songs.isNotEmpty) {
        final repertoire = songs.map((s) {
          try { return jsonDecode(s) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
        }).where((m) => m.isNotEmpty).toList();
        await _db.collection('users').doc(uid).update({'repertoire': repertoire});
      }

      // Sync goals
      final goals = prefs.getStringList('longTermGoals') ?? [];
      if (goals.isNotEmpty) {
        final goalsData = goals.map((s) {
          try { return jsonDecode(s) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
        }).where((m) => m.isNotEmpty).toList();
        await _db.collection('users').doc(uid).update({'goals': goalsData});
      }

      // Sync notes
      final notes = prefs.getStringList('lessonNotes') ?? [];
      if (notes.isNotEmpty) {
        final notesData = notes.map((s) {
          try { return jsonDecode(s) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
        }).where((m) => m.isNotEmpty).toList();
        await _db.collection('users').doc(uid).update({'lessonNotes': notesData});
      }
    } catch (_) {
      // Fail silently
    }
  }

  // --- Get user profile ---
  Future<Map<String, dynamic>?> getUserProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  // --- Sign out ---
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- Password reset ---
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- Delete account ---
  Future<void> deleteAccount() async {
    final uid = currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).delete();
    }
    await currentUser?.delete();
  }

  // --- Helpers ---
  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'An account with this email already exists.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password. Please try again.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      default: return e.message ?? 'Authentication failed.';
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}