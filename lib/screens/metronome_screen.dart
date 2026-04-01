import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  int _bpm = 120;
  bool _isPlaying = false;
  Timer? _timer;
  final TextEditingController _bpmController =
      TextEditingController(text: '120');
  final List<DateTime> _tapTimes = [];
  final List<AudioPlayer> _players =
      List.generate(8, (_) => AudioPlayer());
  int _playerIndex = 0;

  @override
  void initState() {
    super.initState();
    _initPlayers();
  }

  Future<void> _initPlayers() async {
    for (final p in _players) {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(1.0);
      await p.setSource(AssetSource('audio/click.wav'));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final p in _players) {
      p.dispose();
    }
    _bpmController.dispose();
    super.dispose();
  }

  void _tick() {
    final player = _players[_playerIndex % _players.length];
    _playerIndex++;
    player.seek(Duration.zero).then((_) => player.resume());
  }

  void _start() {
    _timer?.cancel();
    _tick();
    final interval =
        Duration(microseconds: (60000000 / _bpm).round());
    _timer = Timer.periodic(interval, (_) => _tick());
    setState(() => _isPlaying = true);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    setState(() => _isPlaying = false);
  }

  void _updateBpm(int newBpm) {
    final clamped = newBpm.clamp(40, 240);
    setState(() {
      _bpm = clamped;
      _bpmController.text = '$clamped';
      _bpmController.selection = TextSelection.fromPosition(
        TextPosition(offset: _bpmController.text.length),
      );
    });
    if (_isPlaying) _start();
  }

  void _tapTempo() {
    final now = DateTime.now();
    _tapTimes.add(now);
    if (_tapTimes.length > 4) _tapTimes.removeAt(0);
    if (_tapTimes.length >= 2) {
      final intervals = <int>[];
      for (int i = 1; i < _tapTimes.length; i++) {
        intervals.add(_tapTimes[i]
            .difference(_tapTimes[i - 1])
            .inMilliseconds);
      }
      final avg =
          intervals.reduce((a, b) => a + b) / intervals.length;
      _updateBpm((60000 / avg).round());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metronome',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // --- BPM Display ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color:
                          Colors.deepPurple.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Text('BPM',
                        style: TextStyle(
                            fontSize: 16,
                            letterSpacing: 3,
                            color: Colors.deepPurple)),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _bpmController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        onChanged: (val) {
                          final bpm = int.tryParse(val);
                          if (bpm != null &&
                              bpm >= 40 &&
                              bpm <= 240) {
                            setState(() => _bpm = bpm);
                            if (_isPlaying) _start();
                          }
                        },
                        onSubmitted: (val) {
                          final bpm =
                              int.tryParse(val) ?? _bpm;
                          _updateBpm(bpm);
                          FocusScope.of(context).unfocus();
                        },
                        onTapOutside: (_) {
                          final bpm = int.tryParse(
                                  _bpmController.text) ??
                              _bpm;
                          _updateBpm(bpm);
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ),
                    Text(
                      'Tap to type  •  40–240',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface
                            .withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- BPM Slider ---
              Row(
                children: [
                  Text('40',
                      style: TextStyle(
                          color: colorScheme.onSurface
                              .withOpacity(0.5))),
                  Expanded(
                    child: Slider(
                      value: _bpm.toDouble(),
                      min: 40,
                      max: 240,
                      divisions: 200,
                      label: '$_bpm BPM',
                      activeColor: Colors.deepPurple,
                      onChanged: (value) {
                        setState(() {
                          _bpm = value.round();
                          _bpmController.text = '$_bpm';
                        });
                      },
                      onChangeEnd: (value) {
                        _updateBpm(value.round());
                      },
                    ),
                  ),
                  Text('240',
                      style: TextStyle(
                          color: colorScheme.onSurface
                              .withOpacity(0.5))),
                ],
              ),
              const SizedBox(height: 32),

              // --- Play/Stop Button ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPlaying ? _stop : _start,
                  icon: Icon(
                    _isPlaying
                        ? Icons.stop
                        : Icons.play_arrow,
                    size: 36,
                  ),
                  label: Text(
                    _isPlaying ? 'Stop' : 'Start',
                    style: const TextStyle(fontSize: 24),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlaying
                        ? Colors.red
                        : Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Tap Tempo ---
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _tapTempo,
                  icon: const Icon(Icons.touch_app,
                      size: 22),
                  label: const Text('Tap Tempo',
                      style: TextStyle(fontSize: 18)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16),
                    side: const BorderSide(
                        color: Colors.deepPurple, width: 2),
                    foregroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}