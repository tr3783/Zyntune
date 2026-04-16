import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class MetronomeService extends ChangeNotifier {
  static final MetronomeService _instance =
      MetronomeService._internal();
  factory MetronomeService() => _instance;

  MetronomeService._internal() {
    _initPlayers();
  }

  int bpm = 120;
  bool isPlaying = false;
  Timer? _timer;
  final List<AudioPlayer> _players =
      List.generate(8, (_) => AudioPlayer());
  int _playerIndex = 0;

  Future<void> _initPlayers() async {
    for (final p in _players) {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(1.0);
      await p.setSource(AssetSource('audio/click.wav'));
    }
  }

  void _tick() {
    final player = _players[_playerIndex % _players.length];
    _playerIndex++;
    player.seek(Duration.zero).then((_) => player.resume());
  }

  void start() {
    _timer?.cancel();
    _playerIndex = 0;

    // Pre-seek all players to eliminate first-beat latency
    for (final p in _players) {
      p.seek(Duration.zero);
    }

    final interval =
        Duration(microseconds: (60000000 / bpm).round());

    // Small delay to let seeks complete before first tick
    Future.delayed(const Duration(milliseconds: 50), () {
      if (isPlaying) {
        _tick();
        _timer = Timer.periodic(interval, (_) => _tick());
      }
    });

    isPlaying = true;
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    isPlaying = false;
    notifyListeners();
  }

  void updateBpm(int newBpm) {
    bpm = newBpm.clamp(40, 240);
    notifyListeners();
    if (isPlaying) start();
  }
}