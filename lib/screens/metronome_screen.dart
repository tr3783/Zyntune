import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:isolate';
import 'metronome_isolate.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  int _bpm = 120;
  bool _isPlaying = false;
  int _beatsPerMeasure = 4;
  int _currentBeat = 0;
  int _currentSubdivision = 0;
  final TextEditingController _bpmController =
      TextEditingController(text: '120');
  final List<DateTime> _tapTimes = [];
  bool _accentBeat1 = true;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _isolateSendPort;

  final List<AudioPlayer> _accentPlayers =
      List.generate(4, (_) => AudioPlayer());
  final List<AudioPlayer> _clickPlayers =
      List.generate(4, (_) => AudioPlayer());
  final List<AudioPlayer> _tickPlayers =
      List.generate(4, (_) => AudioPlayer());
  int _accentIndex = 0;
  int _clickIndex = 0;
  int _tickIndex = 0;

  int _subdivision = 1;
  final Map<int, String> _subdivisionLabels = {
    1: 'Quarter Notes',
    2: '8th Notes',
    3: 'Triplets',
    4: '16th Notes',
  };

  @override
  void initState() {
    super.initState();
    _preloadAudio();
    _initIsolate();
  }

  Future<void> _preloadAudio() async {
    try {
      for (final p in _accentPlayers) {
        await p.setSource(AssetSource('audio/accent.wav'));
        await p.setVolume(1.0);
        await p.setReleaseMode(ReleaseMode.stop);
      }
      for (final p in _clickPlayers) {
        await p.setSource(AssetSource('audio/click.wav'));
        await p.setVolume(1.0);
        await p.setReleaseMode(ReleaseMode.stop);
      }
      for (final p in _tickPlayers) {
        await p.setSource(AssetSource('audio/tick.wav'));
        await p.setVolume(0.6);
        await p.setReleaseMode(ReleaseMode.stop);
      }
    } catch (e) {
      // Silently handle
    }
  }

  Future<void> _initIsolate() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      metronomeIsolateEntry,
      _receivePort!.sendPort,
    );

    _receivePort!.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
      } else if (message is Map) {
        if (message['type'] == 'tick') {
          _onTick(
            isMainBeat: message['isMainBeat'] as bool,
            isFirstBeat: message['isFirstBeat'] as bool,
            currentBeat: message['currentBeat'] as int,
            currentSubdivision:
                message['currentSubdivision'] as int,
          );
        }
      }
    });
  }

  void _onTick({
    required bool isMainBeat,
    required bool isFirstBeat,
    required int currentBeat,
    required int currentSubdivision,
  }) {
    if (isMainBeat) {
      if (_accentBeat1 && isFirstBeat &&
          _beatsPerMeasure > 1) {
        _playAccent();
      } else {
        _playClick();
      }
    } else {
      _playTick();
    }

    if (mounted) {
      setState(() {
        _currentBeat = currentBeat;
        _currentSubdivision = currentSubdivision;
      });
    }
  }

  void _playAccent() {
    final player = _accentPlayers[_accentIndex % 4];
    _accentIndex++;
    player.seek(Duration.zero);
    player.resume();
  }

  void _playClick() {
    final player = _clickPlayers[_clickIndex % 4];
    _clickIndex++;
    player.seek(Duration.zero);
    player.resume();
  }

  void _playTick() {
    final player = _tickPlayers[_tickIndex % 4];
    _tickIndex++;
    player.seek(Duration.zero);
    player.resume();
  }

  void _start() {
    _isolateSendPort?.send({
      'type': 'start',
      'bpm': _bpm,
      'subdivision': _subdivision,
      'beatsPerMeasure': _beatsPerMeasure,
    });
    setState(() => _isPlaying = true);
  }

  void _stop() {
    _isolateSendPort?.send({'type': 'stop'});
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _currentBeat = 0;
        _currentSubdivision = 0;
      });
    }
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
    if (_isPlaying) {
      _stop();
      _start();
    }
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
      final avgInterval =
          intervals.reduce((a, b) => a + b) / intervals.length;
      final newBpm =
          (60000 / avgInterval).round().clamp(40, 240);
      _updateBpm(newBpm);
    }
  }

  @override
  void dispose() {
    _isolateSendPort?.send({'type': 'stop'});
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    for (final p in _accentPlayers) p.dispose();
    for (final p in _clickPlayers) p.dispose();
    for (final p in _tickPlayers) p.dispose();
    _bpmController.dispose();
    super.dispose();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        child: Column(
          children: [

            // --- Beat Indicator Dots ---
            SizedBox(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _beatsPerMeasure == 1
                    ? [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentBeat == 1
                                ? Colors.deepPurple
                                : colorScheme.onSurface
                                    .withOpacity(0.3),
                          ),
                        )
                      ]
                    : List.generate(_beatsPerMeasure,
                        (index) {
                        final isActive =
                            _currentBeat == index + 1;
                        final isFirst = index == 0;
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? (isFirst && _accentBeat1
                                    ? Colors.deepOrange
                                    : Colors.deepPurple)
                                : colorScheme.onSurface
                                    .withOpacity(0.3),
                            border: isFirst && _accentBeat1
                                ? Border.all(
                                    color: Colors.deepOrange
                                        .withOpacity(0.5),
                                    width: 2)
                                : null,
                          ),
                        );
                      }),
              ),
            ),
            const SizedBox(height: 8),

            // --- Subdivision Dots ---
            SizedBox(
              height: 16,
              child: _subdivision > 1
                  ? Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: List.generate(
                          _subdivision, (index) {
                        final isActive =
                            _currentSubdivision == index;
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4),
                          width: isActive ? 10 : 6,
                          height: isActive ? 10 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? Colors.deepPurpleAccent
                                : colorScheme.onSurface
                                    .withOpacity(0.2),
                          ),
                        );
                      }),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // --- BPM Display ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.deepPurple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('BPM',
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _bpmController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onSubmitted: (val) {
                        final bpm = int.tryParse(val) ?? 120;
                        _updateBpm(bpm);
                      },
                      onChanged: (val) {
                        final bpm = int.tryParse(val);
                        if (bpm != null &&
                            bpm >= 40 &&
                            bpm <= 240) {
                          setState(() => _bpm = bpm);
                          if (_isPlaying) {
                            _stop();
                            _start();
                          }
                        }
                      },
                    ),
                  ),
                  Text(
                    'Tap to type  |  Range: 40 - 240',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                    onChanged: (value) =>
                        _updateBpm(value.round()),
                  ),
                ),
                Text('240',
                    style: TextStyle(
                        color: colorScheme.onSurface
                            .withOpacity(0.5))),
              ],
            ),
            const SizedBox(height: 16),

            // --- Beats Per Measure ---
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Beats per measure',
                      style: TextStyle(fontSize: 15)),
                  DropdownButton<int>(
                    value: _beatsPerMeasure,
                    underline: const SizedBox(),
                    items: [1, 2, 3, 4, 6].map((val) {
                      return DropdownMenuItem(
                        value: val,
                        child: Text(
                          val == 1 ? '1 (steady)' : '$val',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _beatsPerMeasure = val;
                          _currentBeat = 0;
                        });
                        if (_isPlaying) {
                          _stop();
                          _start();
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // --- Subdivision ---
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subdivision',
                      style: TextStyle(fontSize: 15)),
                  DropdownButton<int>(
                    value: _subdivision,
                    underline: const SizedBox(),
                    items: _subdivisionLabels.entries
                        .map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _subdivision = val;
                          _currentSubdivision = 0;
                        });
                        if (_isPlaying) {
                          _stop();
                          _start();
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // --- Accent Beat 1 Toggle ---
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text('Accent Beat 1',
                          style: TextStyle(fontSize: 15)),
                      Text(
                        'Higher pitch on the downbeat',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _accentBeat1,
                    onChanged: _beatsPerMeasure > 1
                        ? (val) {
                            setState(
                                () => _accentBeat1 = val);
                            if (_isPlaying) {
                              _stop();
                              _start();
                            }
                          }
                        : null,
                    activeColor: Colors.deepOrange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // --- Play/Stop Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isPlaying ? _stop : _start,
                icon: Icon(
                  _isPlaying ? Icons.stop : Icons.play_arrow,
                  size: 32,
                ),
                label: Text(
                  _isPlaying ? 'Stop' : 'Start',
                  style: const TextStyle(fontSize: 22),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlaying
                      ? Colors.red
                      : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // --- Tap Tempo ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _tapTempo,
                icon: const Icon(Icons.touch_app),
                label: const Text('Tap Tempo',
                    style: TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14),
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
    );
  }
}