import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays a recording file. The player screen's tools (speed, loop, markers)
/// work the same for audio and video through this interface.
abstract class RecordingPlayback {
  factory RecordingPlayback({required bool isVideo}) => isVideo ? _VideoPlayback() : _AudioPlayback();

  void Function(Duration position)? onPosition;
  void Function(Duration duration)? onDuration;
  void Function(bool playing)? onPlayingChanged;
  void Function()? onComplete;

  Future<void> open(String path);
  Future<void> play(double speed);
  Future<void> pause();
  Future<void> seek(Duration to);
  Future<void> setSpeed(double speed);
  Future<void> stop();
  void dispose();

  /// The video to show, or null for audio.
  Widget? view();
}

class _AudioPlayback implements RecordingPlayback {
  final _player = AudioPlayer();
  final List<StreamSubscription> _subs = [];

  @override
  void Function(Duration position)? onPosition;
  @override
  void Function(Duration duration)? onDuration;
  @override
  void Function(bool playing)? onPlayingChanged;
  @override
  void Function()? onComplete;

  @override
  Future<void> open(String path) async {
    _subs.add(_player.onPositionChanged.listen((p) => onPosition?.call(p)));
    _subs.add(_player.onDurationChanged.listen((d) => onDuration?.call(d)));
    _subs.add(_player.onPlayerStateChanged.listen((s) => onPlayingChanged?.call(s == PlayerState.playing)));
    _subs.add(_player.onPlayerComplete.listen((_) => onComplete?.call()));
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(DeviceFileSource(path));
  }

  @override
  Future<void> play(double speed) async {
    await _player.resume();
    await _player.setPlaybackRate(speed);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  // Pitch is kept: audioplayers uses AVPlayer's time-domain pitch algorithm.
  @override
  Future<void> setSpeed(double speed) => _player.setPlaybackRate(speed);

  @override
  Future<void> stop() => _player.stop();

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
  }

  @override
  Widget? view() => null;
}

class _VideoPlayback implements RecordingPlayback {
  VideoPlayerController? _controller;
  bool _wasPlaying = false;
  bool _completed = false;

  @override
  void Function(Duration position)? onPosition;
  @override
  void Function(Duration duration)? onDuration;
  @override
  void Function(bool playing)? onPlayingChanged;
  @override
  void Function()? onComplete;

  @override
  Future<void> open(String path) async {
    final controller = VideoPlayerController.file(File(path));
    _controller = controller;
    controller.addListener(_onChange);
    await controller.initialize();
    onDuration?.call(controller.value.duration);
  }

  void _onChange() {
    final value = _controller?.value;
    if (value == null) return;
    onPosition?.call(value.position);
    if (value.isPlaying != _wasPlaying) {
      _wasPlaying = value.isPlaying;
      onPlayingChanged?.call(value.isPlaying);
    }
    final done = value.isInitialized && value.duration > Duration.zero && value.position >= value.duration && !value.isPlaying;
    if (done && !_completed) onComplete?.call();
    _completed = done;
  }

  @override
  Future<void> play(double speed) async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.position >= controller.value.duration) await controller.seekTo(Duration.zero);
    await controller.setPlaybackSpeed(speed);
    await controller.play();
  }

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> seek(Duration to) async => _controller?.seekTo(to);

  @override
  Future<void> setSpeed(double speed) async => _controller?.setPlaybackSpeed(speed);

  @override
  Future<void> stop() async => _controller?.pause();

  @override
  void dispose() {
    _controller?.removeListener(_onChange);
    _controller?.dispose();
  }

  @override
  Widget? view() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const AspectRatio(aspectRatio: 9 / 16, child: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    return AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller));
  }
}
