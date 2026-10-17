import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'auth_service.dart';
import 'date_format.dart';
import 'purchase_service.dart';
import 'recordings.dart';

enum RecordingStartResult { started, alreadyRecording, needsPro, noPermission, failed }

/// A finished recording that hasn't been saved (named) or discarded yet.
class PendingRecording {
  final String id;
  final String uid;
  final String path;
  final DateTime startedAt;
  final int durationMs;
  // Piece to pre-select when saving (recording started from that piece).
  final String? piece;

  PendingRecording({required this.id, required this.uid, required this.path, required this.startedAt, required this.durationMs, this.piece});
}

/// The app-wide audio recorder. One recording at a time; it keeps going while
/// the user moves around the app or locks the screen (background audio).
class RecordingService extends ChangeNotifier {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  String? _id;
  String? _uid;
  String? _path;
  DateTime? _startedAt;
  String? _piece;

  bool get isRecording => _startedAt != null;
  Duration get elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  /// [piece]: the piece being recorded, if started from that piece's page.
  Future<RecordingStartResult> start({String? piece}) async {
    if (isRecording) return RecordingStartResult.alreadyRecording;
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return RecordingStartResult.failed;
    try {
      final store = RecordingStore(uid);
      if (!PurchaseService().isPro && await store.count() >= RecordingStore.freeLimit) {
        return RecordingStartResult.needsPro;
      }
      if (!await _recorder.hasPermission()) return RecordingStartResult.noPermission;
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final path = await store.newFilePath(id);
      // AAC, mono, ~1 MB per minute. The default iOS options play through the
      // speaker, so the metronome stays audible while recording.
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100, numChannels: 1),
        path: path,
      );
      _id = id;
      _uid = uid;
      _path = path;
      _startedAt = DateTime.now();
      _piece = piece;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
      notifyListeners();
      return RecordingStartResult.started;
    } catch (e) {
      debugPrint('RecordingService start failed: $e');
      return RecordingStartResult.failed;
    }
  }

  /// Stops recording. Returns the recording to save or discard, or null if
  /// nothing was recorded.
  Future<PendingRecording?> stop() async {
    if (!isRecording) return null;
    final startedAt = _startedAt!;
    final pending = (id: _id!, uid: _uid!, path: _path!, piece: _piece);
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _id = null;
    _uid = null;
    _path = null;
    _piece = null;
    notifyListeners();
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('RecordingService stop failed: $e');
    }
    if (!await File(pending.path).exists()) return null;
    return PendingRecording(
      id: pending.id,
      uid: pending.uid,
      path: pending.path,
      startedAt: startedAt,
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      piece: pending.piece,
    );
  }

  Future<Recording> save(PendingRecording pending, {required String title, String piece = '', String movement = '', String notes = ''}) async {
    final recording = Recording(
      id: pending.id,
      fileName: pending.path.split('/').last,
      createdAt: pending.startedAt,
      durationMs: pending.durationMs,
      title: title,
      piece: piece,
      movement: movement,
      notes: notes,
    );
    await RecordingStore(pending.uid).add(recording);
    return recording;
  }

  Future<void> discard(PendingRecording pending) async {
    final file = File(pending.path);
    if (await file.exists()) await file.delete();
  }

  /// Signing out mid-recording: keep it, saved under its owner with a default
  /// name, rather than losing it.
  Future<void> stopAndKeepForSignOut() async {
    final pending = await stop();
    if (pending != null) await save(pending, title: defaultTitle(pending.startedAt));
  }

  static String defaultTitle(DateTime startedAt) => 'Recording — ${formatFullDate(startedAt)}';
}
