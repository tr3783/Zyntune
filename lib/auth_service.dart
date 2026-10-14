import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'push_notification_service.dart';
import 'account_data_service.dart';
import 'purchase_service.dart';

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
    // Data already on the phone belongs to someone else; don't let the new
    // account claim it.
    AccountDataService().markNextSignInAsNewAccount();
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
      await PushNotificationService().loginUser(credential.user!.uid);
      await PurchaseService().refreshGrandfathering();
      return credential;
    } on FirebaseAuthException catch (e) {
      AccountDataService().clearNewAccountMark();
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
      await PushNotificationService().loginUser(credential.user!.uid);
      await PurchaseService().refreshGrandfathering();
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
    // Back up and clear this account's data so the next person to sign in
    // on this device doesn't see it.
    await AccountDataService().backupAndClear();
    await PushNotificationService().logoutUser();
    await _auth.signOut();
  }

  // --- Password reset ---
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- Delete account ---
  Future<void> deleteAccount() async {
    const reloginMessage =
        'For security, please sign out and sign back in before deleting your account.';
    final user = currentUser;
    if (user == null) return;

    // Firebase only allows deleting an account shortly after sign-in.
    // Check this before touching any data so a refused deletion
    // never leaves the user with an account but no data.
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null ||
        DateTime.now().difference(lastSignIn) > const Duration(minutes: 5)) {
      throw reloginMessage;
    }

    try {
      final userDoc = _db.collection('users').doc(user.uid);
      // Deleting a document doesn't delete its subcollections,
      // so remove practice history and assignments explicitly.
      await _deleteCollection(userDoc.collection('sessions'));
      await _deleteCollection(userDoc.collection('assignments'));
      await userDoc.delete();
      await user.delete();
      await AccountDataService().clearForDeletedAccount(user.uid);
      await PushNotificationService().logoutUser();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw reloginMessage;
      }
      throw e.message ?? 'Failed to delete account.';
    } on FirebaseException catch (e) {
      throw e.message ?? 'Failed to delete account data.';
    }
  }

  Future<void> _deleteCollection(CollectionReference collection) async {
    // Firestore batches are limited to 500 writes.
    while (true) {
      final snapshot = await collection.limit(500).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // --- Helpers ---
  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'An account with this email already exists.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password. Please try again.';
      // Newer Firebase reports a wrong password or unknown email as this.
      case 'invalid-credential': return 'Incorrect email or password. Please try again.';
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