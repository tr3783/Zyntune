import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

enum _Kind { stringList, string, integer, boolean }

/// Keeps each account's personal data separate on a shared device.
///
/// Personal data is stored on the phone (SharedPreferences) and backed up to
/// the signed-in account in Firestore: practice sessions in
/// users/{uid}/sessions, everything else in the `appData` map on users/{uid}.
/// The phone remembers whose data it holds (`dataOwnerUid`), so one account's
/// data is never uploaded into another account.
///
/// If a backup can't finish (e.g. offline), data is never discarded: it's
/// "parked" on the phone under its owner's uid and merged back in when that
/// same account signs in again.
class AccountDataService {
  static final AccountDataService _instance = AccountDataService._internal();
  factory AccountDataService() => _instance;
  AccountDataService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Personal data that belongs to an account. Everything else in
  // SharedPreferences is a device setting and stays with the phone.
  // Practice sessions ('practiceSessions') are handled separately.
  static const Map<String, _Kind> _personalKeys = {
    'songs': _Kind.stringList,
    'longTermGoals': _Kind.stringList,
    'lessonNotes': _Kind.stringList,
    'calendarEvents': _Kind.stringList,
    'instruments': _Kind.stringList,
    'achievements': _Kind.string,
    'lastPracticeDate': _Kind.string,
    'streakFreezeUsedDate': _Kind.string,
    'lastReportCardShown': _Kind.string,
    'parentEmail': _Kind.string,
    'activeInstrument': _Kind.string,
    'instrument': _Kind.string,
    'userName': _Kind.string,
    'practicePoints': _Kind.integer,
    'currentStreak': _Kind.integer,
    'longestStreak': _Kind.integer,
    'dailyGoalMinutes': _Kind.integer,
    'streakFreezeActive': _Kind.boolean,
    'onboardingComplete': _Kind.boolean,
  };
  static const _sessionsKey = 'practiceSessions';

  static const _ownerKey = 'dataOwnerUid';
  static const _syncedHashKey = 'accountDataSyncedHash';
  static const _syncedAtKey = 'accountDataSyncedAt';
  static const _parkedPrefix = 'parkedData_';
  static const _legacyParkId = 'legacy';

  // Firestore batches are limited to 500 writes.
  static const _batchSize = 450;
  static const _timeout = Duration(seconds: 15);

  final Map<String, Future<void>> _ready = {};
  bool _nextSignInIsNewAccount = false;
  Future<bool>? _syncInFlight;

  /// Call before creating a brand-new account, so data already on the phone
  /// (which belongs to someone else) isn't claimed by it.
  void markNextSignInAsNewAccount() => _nextSignInIsNewAccount = true;

  /// Call if creating the account failed.
  void clearNewAccountMark() => _nextSignInIsNewAccount = false;

  /// Makes sure the phone holds [uid]'s data. Called by AuthGate before showing
  /// the app for a signed-in user; safe to call repeatedly.
  Future<void> ensureReady(String uid) => _ready[uid] ??= _prepare(uid);

  Future<void> _prepare(String uid) async {
    final isNewAccount = _nextSignInIsNewAccount;
    _nextSignInIsNewAccount = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final owner = prefs.getString(_ownerKey);

      if (owner == uid) {
        await sync();
        return;
      }

      if (owner != null) {
        // Another account's data is on the phone (it signed out without our
        // sign-out flow). Set it aside for that account.
        await _park(prefs, owner);
      } else if (_hasPersonalData(prefs)) {
        // Data from before 2.5.1, when the phone didn't track an owner.
        // Older versions merged it into whoever signed in, so an existing
        // account claims it; a brand-new account must not.
        if (isNewAccount) await _park(prefs, _legacyParkId);
      }

      await prefs.setString(_ownerKey, uid);
      await prefs.remove(_syncedHashKey);
      await prefs.remove(_syncedAtKey);

      if (isNewAccount) {
        // Nothing to restore yet; onboarding sets things up and the next
        // sync backs them up. (The profile doc may not exist yet.)
        await prefs.setBool('onboardingComplete', false);
        return;
      }

      await _restoreParked(prefs, uid);
      await _restoreParked(prefs, _legacyParkId);
      await sync();
    } catch (e) {
      debugPrint('AccountDataService prepare failed: $e');
    }
  }

  /// Two-way sync of the signed-in account's data. Returns true on success.
  Future<bool> sync() => _syncInFlight ??= _sync().whenComplete(() => _syncInFlight = null);

  Future<bool> _sync() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_ownerKey) != uid) return false;

      final docRef = _db.collection('users').doc(uid);
      final doc = await docRef.get().timeout(_timeout);
      if (!doc.exists) return false;
      final docData = doc.data() ?? {};

      final local = _readLocal(prefs);
      final cloud = _cloudAppData(docData);
      final cloudUpdatedAt = docData['appDataUpdatedAt'] as int?;
      final lastSyncedAt = prefs.getInt(_syncedAtKey);

      // Changed since this phone last synced? (Data saved by older versions
      // has no timestamp; it counts as new until the first sync.)
      final localChanged = _hash(local) != prefs.getString(_syncedHashKey);
      final cloudChanged = cloudUpdatedAt == null ? lastSyncedAt == null : cloudUpdatedAt != lastSyncedAt;

      final result = localChanged && cloudChanged
          ? _merge(local, cloud)
          : cloudChanged
              ? cloud
              : local;

      if (cloudChanged) await _writeLocal(prefs, result);
      final sessions = await _syncSessions(prefs, uid);

      if (localChanged) {
        await _push(prefs, docRef, result, sessions);
      } else {
        await prefs.setString(_syncedHashKey, _hash(result));
        if (cloudUpdatedAt != null) await prefs.setInt(_syncedAtKey, cloudUpdatedAt);
      }
      return true;
    } catch (e) {
      debugPrint('AccountDataService sync failed: $e');
      return false;
    }
  }

  /// Sign-out: back up, then clear this account's data from the phone.
  /// If the backup can't finish, the data is parked for this account instead
  /// of lost.
  Future<void> backupAndClear() async {
    final uid = AuthService().currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(_ownerKey);
    if (uid != null && owner == uid) {
      final ok = await sync();
      if (!ok) await _park(prefs, uid);
    } else if (owner != null) {
      await _park(prefs, owner);
    }
    await _clearPersonal(prefs);
    await prefs.remove(_ownerKey);
    await prefs.remove(_syncedHashKey);
    await prefs.remove(_syncedAtKey);
    _ready.clear();
  }

  /// Account deletion: remove this account's data from the phone entirely.
  Future<void> clearForDeletedAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await _clearPersonal(prefs);
    await prefs.remove('$_parkedPrefix$uid');
    await prefs.remove(_ownerKey);
    await prefs.remove(_syncedHashKey);
    await prefs.remove(_syncedAtKey);
    _ready.clear();
  }

  // --- Local data ---

  bool _hasPersonalData(SharedPreferences prefs) =>
      (prefs.getStringList(_sessionsKey)?.isNotEmpty ?? false) ||
      _personalKeys.keys.any(prefs.containsKey);

  Map<String, dynamic> _readLocal(SharedPreferences prefs) {
    final data = <String, dynamic>{};
    for (final entry in _personalKeys.entries) {
      final value = switch (entry.value) {
        _Kind.stringList => prefs.getStringList(entry.key),
        _Kind.string => prefs.getString(entry.key),
        _Kind.integer => prefs.getInt(entry.key),
        _Kind.boolean => prefs.getBool(entry.key),
      };
      if (value != null) data[entry.key] = value;
    }
    return data;
  }

  Future<void> _writeLocal(SharedPreferences prefs, Map<String, dynamic> data) async {
    for (final entry in _personalKeys.entries) {
      final value = data[entry.key];
      if (value == null) {
        await prefs.remove(entry.key);
        continue;
      }
      switch (entry.value) {
        case _Kind.stringList:
          await prefs.setStringList(entry.key, List<String>.from((value as List).map((e) => e.toString())));
        case _Kind.string:
          await prefs.setString(entry.key, value.toString());
        case _Kind.integer:
          if (value is num) await prefs.setInt(entry.key, value.toInt());
        case _Kind.boolean:
          if (value is bool) await prefs.setBool(entry.key, value);
      }
    }
  }

  Future<void> _clearPersonal(SharedPreferences prefs) async {
    for (final key in _personalKeys.keys) {
      await prefs.remove(key);
    }
    await prefs.remove(_sessionsKey);
  }

  // --- Parking: data set aside on the phone for one specific account ---

  Future<void> _park(SharedPreferences prefs, String parkId) async {
    final key = '$_parkedPrefix$parkId';
    final existing = _decodeParked(prefs.getString(key));
    final appData = _merge(_readLocal(prefs), existing.$1);
    final sessions = _mergeSessions(prefs.getStringList(_sessionsKey) ?? [], existing.$2);
    if (appData.isNotEmpty || sessions.isNotEmpty) {
      await prefs.setString(key, jsonEncode({'appData': appData, 'sessions': sessions}));
    }
    await _clearPersonal(prefs);
  }

  Future<void> _restoreParked(SharedPreferences prefs, String parkId) async {
    final key = '$_parkedPrefix$parkId';
    final raw = prefs.getString(key);
    if (raw == null) return;
    final parked = _decodeParked(raw);
    await _writeLocal(prefs, _merge(_readLocal(prefs), parked.$1));
    await prefs.setStringList(_sessionsKey, _mergeSessions(prefs.getStringList(_sessionsKey) ?? [], parked.$2));
    await prefs.remove(key);
  }

  (Map<String, dynamic>, List<String>) _decodeParked(String? raw) {
    if (raw == null) return (<String, dynamic>{}, <String>[]);
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (
        Map<String, dynamic>.from(map['appData'] as Map? ?? {}),
        List<String>.from((map['sessions'] as List? ?? []).map((e) => e.toString())),
      );
    } catch (_) {
      return (<String, dynamic>{}, <String>[]);
    }
  }

  // --- Cloud data ---

  /// The account's app data, or for accounts that haven't synced from 2.5.1+
  /// yet, what older versions backed up in top-level fields.
  Map<String, dynamic> _cloudAppData(Map<String, dynamic> doc) {
    final appData = doc['appData'];
    if (appData is Map) return Map<String, dynamic>.from(appData);

    final legacy = <String, dynamic>{};
    List<String>? encodeList(Object? list) =>
        list is List && list.isNotEmpty ? list.map((e) => e is String ? e : jsonEncode(e)).toList() : null;
    final songs = encodeList(doc['repertoire']);
    final goals = encodeList(doc['goals']);
    final notes = encodeList(doc['lessonNotes']);
    if (songs != null) legacy['songs'] = songs;
    if (goals != null) legacy['longTermGoals'] = goals;
    if (notes != null) legacy['lessonNotes'] = notes;
    if (doc['currentStreak'] is int) legacy['currentStreak'] = doc['currentStreak'];
    if (doc['longestStreak'] is int) legacy['longestStreak'] = doc['longestStreak'];
    if (doc['name'] is String) legacy['userName'] = doc['name'];
    if (doc['instrument'] is String) {
      legacy['instrument'] = doc['instrument'];
      legacy['instruments'] = [doc['instrument']];
    }
    if (doc['parentEmail'] is String) legacy['parentEmail'] = doc['parentEmail'];
    // An existing account has been through onboarding already.
    legacy['onboardingComplete'] = true;
    return legacy;
  }

  Future<void> _push(
    SharedPreferences prefs,
    DocumentReference<Map<String, dynamic>> docRef,
    Map<String, dynamic> data,
    List<String> sessions,
  ) async {
    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    List<Map<String, dynamic>> decodeList(String key) => List<String>.from(data[key] as List? ?? [])
        .map((s) {
          try { return jsonDecode(s) as Map<String, dynamic>; } catch (_) { return <String, dynamic>{}; }
        })
        .where((m) => m.isNotEmpty)
        .toList();
    final totalMinutes = sessions.fold<int>(0, (total, s) {
      try { return total + ((jsonDecode(s) as Map)['durationMinutes'] as num? ?? 0).toInt(); } catch (_) { return total; }
    });

    await docRef.update({
      'appData': data,
      'appDataUpdatedAt': updatedAt,
      // Fields the teacher's studio view reads.
      'repertoire': decodeList('songs'),
      'goals': decodeList('longTermGoals'),
      'lessonNotes': decodeList('lessonNotes'),
      'currentStreak': data['currentStreak'] ?? 0,
      'longestStreak': data['longestStreak'] ?? 0,
      'totalSessions': sessions.length,
      'totalMinutes': totalMinutes,
      'lastSyncedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
    await prefs.setString(_syncedHashKey, _hash(data));
    await prefs.setInt(_syncedAtKey, updatedAt);
  }

  /// Uploads sessions the account is missing (in batches, so long histories
  /// work) and adds the account's sessions the phone is missing.
  Future<List<String>> _syncSessions(SharedPreferences prefs, String uid) async {
    final col = _db.collection('users').doc(uid).collection('sessions');
    final snapshot = await col.get().timeout(_timeout);

    final cloudSessions = <String>[];
    final cloudIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data())..remove('savedAt');
      data['id'] = data['id'] ?? doc.id;
      data.removeWhere((_, v) => v is Timestamp || v is FieldValue);
      cloudIds.add(data['id'].toString());
      cloudSessions.add(jsonEncode(data));
    }

    final local = prefs.getStringList(_sessionsKey) ?? [];
    final missing = <Map<String, dynamic>>[];
    for (final s in local) {
      try {
        final session = jsonDecode(s) as Map<String, dynamic>;
        final id = session['id']?.toString();
        if (id != null && id.isNotEmpty && !cloudIds.contains(id)) missing.add(session);
      } catch (_) {}
    }
    for (var i = 0; i < missing.length; i += _batchSize) {
      final batch = _db.batch();
      for (final session in missing.skip(i).take(_batchSize)) {
        batch.set(col.doc(session['id'].toString()), {...session, 'savedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
      }
      await batch.commit().timeout(_timeout);
    }

    final merged = _mergeSessions(local, cloudSessions);
    await prefs.setStringList(_sessionsKey, merged);
    return merged;
  }

  // --- Merging (used when both sides changed) ---

  Map<String, dynamic> _merge(Map<String, dynamic> local, Map<String, dynamic> other) {
    final result = Map<String, dynamic>.from(other);
    for (final entry in local.entries) {
      final key = entry.key;
      final mine = entry.value;
      final theirs = other[key];
      if (theirs == null) {
        result[key] = mine;
      } else if (_personalKeys[key] == _Kind.stringList && mine is List && theirs is List) {
        result[key] = _mergeList(List<String>.from(mine.map((e) => e.toString())),
            List<String>.from(theirs.map((e) => e.toString())));
      } else if (key == 'currentStreak' || key == 'longestStreak' || key == 'practicePoints') {
        result[key] = (mine is num && theirs is num && theirs > mine) ? theirs : mine;
      } else {
        result[key] = mine;
      }
    }
    return result;
  }

  /// Union of two lists of JSON items, matched by 'id' (or 'title'), with the
  /// phone's version winning when both have the same item.
  List<String> _mergeList(List<String> mine, List<String> theirs) {
    String keyOf(String item) {
      try {
        final map = jsonDecode(item);
        if (map is Map) return (map['id'] ?? map['title'] ?? item).toString();
      } catch (_) {}
      return item;
    }
    final merged = <String, String>{};
    for (final item in theirs) {
      merged[keyOf(item)] = item;
    }
    for (final item in mine) {
      merged[keyOf(item)] = item;
    }
    return merged.values.toList();
  }

  /// Sessions are stored oldest first (the timer screen relies on this).
  List<String> _mergeSessions(List<String> mine, List<String> theirs) {
    final merged = _mergeList(mine, theirs);
    merged.sort((a, b) {
      try {
        return ((jsonDecode(a) as Map)['date'] as String).compareTo((jsonDecode(b) as Map)['date'] as String);
      } catch (_) {
        return 0;
      }
    });
    return merged;
  }

  // --- Test hooks for the pure merge/park logic ---

  @visibleForTesting
  Map<String, dynamic> mergeForTest(Map<String, dynamic> local, Map<String, dynamic> other) => _merge(local, other);
  @visibleForTesting
  List<String> mergeSessionsForTest(List<String> mine, List<String> theirs) => _mergeSessions(mine, theirs);
  @visibleForTesting
  Map<String, dynamic> cloudAppDataForTest(Map<String, dynamic> doc) => _cloudAppData(doc);
  @visibleForTesting
  Map<String, dynamic> readLocalForTest(SharedPreferences prefs) => _readLocal(prefs);
  @visibleForTesting
  Future<void> parkForTest(SharedPreferences prefs, String parkId) => _park(prefs, parkId);
  @visibleForTesting
  Future<void> restoreParkedForTest(SharedPreferences prefs, String parkId) => _restoreParked(prefs, parkId);

  String _hash(Map<String, dynamic> data) {
    final sorted = Map.fromEntries(data.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
  }
}
