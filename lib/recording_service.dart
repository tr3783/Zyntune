import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'auth_service.dart';
import 'date_format.dart';
import 'device_files.dart';
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
  final bool isVideo;
  // Stopped by a phone call or another app taking the microphone.
  final bool interrupted;

  PendingRecording({
    required this.id,
    required this.uid,
    required this.path,
    required this.startedAt,
    required this.durationMs,
    this.piece,
    this.isVideo = false,
    this.interrupted = false,
  });
}

/// The app-wide audio recorder. One recording at a time; it keeps going while
/// the user moves around the app or locks the screen (background audio).
class RecordingService extends ChangeNotifier {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal() {
    DeviceFiles.onAudioInterrupted(_onInterrupted);
  }

  /// Shows the save dialog for a recording stopped by an interruption
  /// (set up in main.dart).
  void Function(PendingRecording pending)? onStoppedByInterruption;

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  String? _id;
  String? _uid;
  String? _path;
  DateTime? _startedAt;
  String? _piece;
  Timer? _meterTimer;
  // Watchdog: iOS doesn't always tell the app when something (e.g. Siri)
  // takes the microphone, but the file then stops growing.
  int _lastSize = -1;
  DateTime? _lastGrowth;
  static const _stalledAfter = Duration(seconds: 5);
  // Files being recorded or waiting in a Save dialog; recovery skips them.
  final Set<String> _inUse = {};
  Set<String> get filesInUse => Set.unmodifiable(_inUse);

  /// Microphone level while recording, 0 (silent) to 1 (loud), for the meter.
  /// Separate from notifyListeners so the whole app doesn't rebuild 8×/sec.
  final ValueNotifier<double> level = ValueNotifier(0);

  bool get isRecording => _startedAt != null;
  Duration get elapsed => _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  /// [piece]: the piece being recorded, if started from that piece's page.
  Future<RecordingStartResult> start({String? piece}) async {
    if (isRecording) return RecordingStartResult.alreadyRecording;
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return RecordingStartResult.failed;
    try {
      final store = RecordingStore(uid);
      if (!PurchaseService().isPro && await store.audioCount() >= RecordingStore.freeLimit) {
        return RecordingStartResult.needsPro;
      }
      if (!await _recorder.hasPermission()) return RecordingStartResult.noPermission;
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final path = await store.newFilePath(id);
      // AAC, mono, ~1 MB per minute. The default iOS options play through the
      // speaker, so the metronome stays audible while recording.
      await _recorder.start(
        // Interruptions (phone calls) are handled in _onInterrupted.
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
          audioInterruption: AudioInterruptionMode.none,
        ),
        path: path,
      );
      _id = id;
      _uid = uid;
      _path = path;
      _startedAt = DateTime.now();
      _piece = piece;
      _inUse.add(path);
      _lastSize = -1;
      _lastGrowth = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
        _checkStillRecording();
      });
      _meterTimer = Timer.periodic(const Duration(milliseconds: 120), (_) => _updateLevel());
      notifyListeners();
      return RecordingStartResult.started;
    } catch (e) {
      debugPrint('RecordingService start failed: $e');
      return RecordingStartResult.failed;
    }
  }

  Future<void> _checkStillRecording() async {
    final path = _path;
    if (path == null) return;
    try {
      final size = await File(path).length();
      final now = DateTime.now();
      if (size != _lastSize) {
        _lastSize = size;
        _lastGrowth = now;
      } else if (_lastGrowth != null && now.difference(_lastGrowth!) > _stalledAfter && _path == path) {
        debugPrint('RecordingService: file stopped growing; treating as interrupted');
        _lastGrowth = null;
        await _onInterrupted();
      }
    } catch (_) {}
  }

  Future<void> _updateLevel() async {
    try {
      final amp = await _recorder.getAmplitude();
      if (!isRecording) return;
      // dBFS: about -50 is quiet room noise, 0 is the loudest possible.
      level.value = ((amp.current + 50) / 50).clamp(0.0, 1.0);
    } catch (_) {}
  }

  /// A phone call or another app took the microphone: stop and keep what was
  /// recorded, rather than leaving the bar saying "Recording" over silence.
  Future<void> _onInterrupted() async {
    if (!isRecording) return;
    final pending = await stop(interrupted: true);
    if (pending == null) return;
    final show = onStoppedByInterruption;
    if (show != null) {
      show(pending);
    } else {
      await save(pending, title: defaultTitle(pending.startedAt));
    }
  }

  /// Stops recording. Returns the recording to save or discard, or null if
  /// nothing was recorded.
  Future<PendingRecording?> stop({bool interrupted = false}) async {
    if (!isRecording) return null;
    final startedAt = _startedAt!;
    final pending = (id: _id!, uid: _uid!, path: _path!, piece: _piece);
    _ticker?.cancel();
    _ticker = null;
    _meterTimer?.cancel();
    _meterTimer = null;
    level.value = 0;
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
    if (!await File(pending.path).exists()) {
      _inUse.remove(pending.path);
      return null;
    }
    return PendingRecording(
      id: pending.id,
      uid: pending.uid,
      path: pending.path,
      startedAt: startedAt,
      // The file's own length; the clock would count time after an
      // interruption silently stopped the recorder.
      durationMs: await Mp4Duration.read(pending.path) ?? DateTime.now().difference(startedAt).inMilliseconds,
      piece: pending.piece,
      interrupted: interrupted,
    );
  }

  Future<Recording> save(PendingRecording pending, {required String title, String piece = '', String movement = '', String notes = ''}) async {
    final recording = Recording(
      id: pending.id,
      fileName: pending.path.split('/').last,
      createdAt: pending.startedAt,
      durationMs: pending.durationMs,
      isVideo: pending.isVideo,
      title: title,
      piece: piece,
      movement: movement,
      notes: notes,
    );
    await RecordingStore(pending.uid).add(recording);
    _inUse.remove(pending.path);
    return recording;
  }

  /// Moves a finished camera recording into the account's recordings folder,
  /// kept out of iCloud Backup. Returns it ready to save or discard.
  Future<PendingRecording?> adoptVideo(String tempPath, {required DateTime startedAt, required int durationMs, String? piece}) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return null;
    final id = startedAt.millisecondsSinceEpoch.toString();
    final ext = tempPath.contains('.') ? tempPath.split('.').last.toLowerCase() : 'mp4';
    final dest = await RecordingStore(uid).newFilePath(id, extension: ext);
    try {
      await File(tempPath).rename(dest);
    } catch (_) {
      // Different volume: copy instead.
      await File(tempPath).copy(dest);
      await File(tempPath).delete();
    }
    _inUse.add(dest);
    await DeviceFiles.excludeFromBackup(dest);
    // The video's own length: iOS skips the time the camera was paused (e.g.
    // while Siri was open), which the clock would still count.
    final fileMs = await Mp4Duration.read(dest);
    return PendingRecording(id: id, uid: uid, path: dest, startedAt: startedAt, durationMs: fileMs ?? durationMs, piece: piece, isVideo: true);
  }

  Future<void> discard(PendingRecording pending) async {
    _inUse.remove(pending.path);
    final file = File(pending.path);
    if (await file.exists()) await file.delete();
  }

  /// Signing out mid-recording: keep it, saved under its owner with a default
  /// name, rather than losing it.
  Future<void> stopAndKeepForSignOut() async {
    final pending = await stop();
    if (pending != null) await save(pending, title: defaultTitle(pending.startedAt));
  }

  static String defaultTitle(DateTime startedAt, {bool video = false}) =>
      '${video ? 'Video' : 'Recording'} — ${formatFullDate(startedAt)}';
}
