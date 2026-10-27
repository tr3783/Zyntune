import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../device_files.dart';
import '../recording_service.dart';
import 'metronome_control.dart';
import 'recording_flow.dart';

/// Full-screen camera for recording practice video (Pro). Video can't record
/// with the screen locked, so the screen is kept awake while recording; if the
/// app leaves the screen, recording stops and what was recorded is offered
/// for saving.
class VideoRecordScreen extends StatefulWidget {
  final String? piece;
  const VideoRecordScreen({super.key, this.piece});

  @override
  State<VideoRecordScreen> createState() => _VideoRecordScreenState();
}

class _VideoRecordScreenState extends State<VideoRecordScreen> with WidgetsBindingObserver {
  static const _recordRed = Color(0xFFE53935);
  // Warn before recording if the phone has less than this much space.
  static const _lowSpaceBytes = 1024 * 1024 * 1024;

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  String? _error;
  bool _recording = false;
  bool _busy = false;
  DateTime? _startedAt;
  Timer? _ticker;
  PendingRecording? _pendingAfterInterruption;
  // 3-2-1 before recording starts, so there's time to get into position.
  int? _countdown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    DeviceFiles.setKeepScreenOn(false);
    final controller = _controller;
    if (_recording && controller != null) {
      // Closed some other way mid-recording: keep the video with a default name.
      _saveOnClose(controller, _startedAt ?? DateTime.now(), widget.piece);
    } else {
      controller?.dispose();
    }
    super.dispose();
  }

  static Future<void> _saveOnClose(CameraController controller, DateTime startedAt, String? piece) async {
    try {
      final file = await controller.stopVideoRecording();
      final pending = await RecordingService().adoptVideo(
        file.path,
        startedAt: startedAt,
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
        piece: piece,
      );
      if (pending != null) {
        await RecordingService().save(pending, title: RecordingService.defaultTitle(startedAt, video: true));
      }
    } catch (e) {
      debugPrint('Saving video on close failed: $e');
    } finally {
      await controller.dispose();
    }
  }

  /// Swiping back while recording stops and offers to save, instead of
  /// throwing the video away.
  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    if (_countdown != null) {
      setState(() => _countdown = null);
    } else if (_recording && !_busy) {
      _stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // iOS stops the camera in the background: finish the recording now.
      if (_recording) _stop(interrupted: true);
      if (_countdown != null) setState(() => _countdown = null);
    } else if (state == AppLifecycleState.resumed) {
      final pending = _pendingAfterInterruption;
      _pendingAfterInterruption = null;
      if (_controller == null || !_controller!.value.isInitialized) _openCamera();
      if (pending != null && mounted) showSaveRecordingDialog(context, pending).then((_) => _closeIfSaved());
    }
  }

  Future<void> _setUp() async {
    if (RecordingService().isRecording) {
      setState(() => _error = 'Stop the audio recording first, then record video.');
      return;
    }
    // The camera plugin asks for camera and microphone access itself when
    // the camera opens (see _openCamera).
    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = [];
    }
    if (_cameras.isEmpty) {
      setState(() => _error = 'No camera is available on this device.');
      return;
    }
    // Start with the front camera so you can see yourself.
    final front = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    _cameraIndex = front == -1 ? 0 : front;
    await _openCamera();
  }

  Future<void> _openCamera() async {
    if (_cameras.isEmpty) return;
    final old = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await old?.dispose();
    // 720p keeps files to roughly 40–60 MB per minute.
    final controller = CameraController(_cameras[_cameraIndex], ResolutionPreset.high, enableAudio: true);
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      final denied = e.code.contains('AccessDenied') || e.code.contains('AccessRestricted');
      setState(() => _error = denied ? _accessMessage : 'Couldn\'t open the camera.');
    } catch (_) {
      setState(() => _error = 'Couldn\'t open the camera.');
    }
  }

  static const _accessMessage = 'Zyntune needs camera and microphone access to record video. You can allow it in iPhone Settings.';

  Future<void> _switchCamera() async {
    if (_recording || _cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _openCamera();
  }

  Future<void> _start() async {
    final controller = _controller;
    if (controller == null || _busy) return;
    final free = await DeviceFiles.freeDiskSpace();
    if (free != null && free < _lowSpaceBytes && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A0A4E),
          title: const Text('Low Storage', style: TextStyle(color: Colors.white)),
          content: Text(
            'This iPhone has ${(free / (1024 * 1024)).round()} MB free. Video uses about 50 MB per minute, so a long recording may not fit.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record Anyway')),
          ],
        ),
      );
      if (go != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    for (var n = 3; n > 0; n--) {
      setState(() => _countdown = n);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      // Cancelled (tapped again) or the app left the screen.
      if (_countdown == null || _controller != controller) {
        setState(() {
          _countdown = null;
          _busy = false;
        });
        return;
      }
    }
    setState(() => _countdown = null);
    try {
      await controller.startVideoRecording();
      await DeviceFiles.setKeepScreenOn(true);
      _startedAt = DateTime.now();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn\'t start recording video.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop({bool interrupted = false}) async {
    final controller = _controller;
    if (controller == null || !_recording) return;
    _ticker?.cancel();
    final startedAt = _startedAt ?? DateTime.now();
    setState(() {
      _recording = false;
      _busy = true;
    });
    await DeviceFiles.setKeepScreenOn(false);
    PendingRecording? pending;
    try {
      final file = await controller.stopVideoRecording();
      pending = await RecordingService().adoptVideo(
        file.path,
        startedAt: startedAt,
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
        piece: widget.piece,
      );
    } catch (e) {
      debugPrint('Stopping video failed: $e');
    }
    if (mounted) setState(() => _busy = false);
    if (pending == null) return;
    if (interrupted) {
      // Show the save dialog when the user comes back to the app.
      _pendingAfterInterruption = pending;
      return;
    }
    if (mounted) await showSaveRecordingDialog(context, pending);
    _closeIfSaved();
  }

  void _closeIfSaved() {
    if (mounted) Navigator.of(context).pop();
  }

  String _elapsed() {
    final d = _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: !_recording && _countdown == null && !_busy,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: [
            // Camera preview
            if (controller != null && controller.value.isInitialized)
              Center(child: CameraPreview(controller))
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    if (_error == _accessMessage) ...[
                      const SizedBox(height: 16),
                      const ElevatedButton(onPressed: openAppSettings, child: Text('Open Settings')),
                    ],
                  ]),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            // 3-2-1 countdown
            if (_countdown != null)
              Center(
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
                  ),
                ),
              ),

            // Top bar: close, timer, switch camera
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(children: [
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: _recording || _countdown != null ? null : () => Navigator.pop(context),
                ),
                const Spacer(),
                if (_recording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _recordRed, borderRadius: BorderRadius.circular(16)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                      const SizedBox(width: 6),
                      Text(_elapsed(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                    ]),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Switch camera',
                  icon: Icon(Icons.cameraswitch, color: _recording || _cameras.length < 2 ? Colors.white24 : Colors.white, size: 28),
                  onPressed: _recording || _countdown != null ? null : _switchCamera,
                ),
              ]),
            ),

            // Record / stop button
            if (controller != null && controller.value.isInitialized)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Column(children: [
                  const MetronomeControl(),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _countdown != null
                        ? () => setState(() => _countdown = null)
                        : _busy
                            ? null
                            : (_recording ? _stop : _start),
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _recordRed,
                          borderRadius: BorderRadius.circular(_recording ? 8 : 40),
                        ),
                        margin: EdgeInsets.all(_recording ? 14 : 0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _recording
                        ? 'Keep Zyntune open while recording video'
                        : _countdown != null
                            ? 'Tap to cancel'
                            : 'Videos are stored only on this iPhone',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
