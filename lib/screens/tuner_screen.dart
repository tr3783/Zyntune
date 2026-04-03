import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  bool _isListening = false;
  double _currentPitch = 0.0;
  String _detectedNote = '--';
  double _cents = 0.0;
  bool _disposed = false;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  final List<int> _buffer = [];

  static const int _sampleRate = 44100;
  static const int _bufferSize = 4096;

  final List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  final Map<String, double> _referenceNotes = {
    'A4 (Concert A)': 440.00,
    'E4': 329.63,
    'D4': 293.66,
    'G4': 392.00,
    'B3': 246.94,
    'C4 (Middle C)': 261.63,
  };

  @override
  void dispose() {
    _disposed = true;
    _audioSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    try {
      final hasPermission =
          await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission denied. Go to Settings → Zyntune → Microphone.'
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      if (mounted) setState(() => _isListening = true);

      _audioSub = stream.listen((data) {
        _buffer.addAll(data);
        while (_buffer.length >= _bufferSize * 2) {
          _processBuffer();
          _buffer.removeRange(0, _bufferSize);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _processBuffer() async {
    if (_disposed) return;
    try {
      final bytes = Uint8List.fromList(
          _buffer.take(_bufferSize * 2).toList());
      final detector = PitchDetector(
        audioSampleRate: _sampleRate.toDouble(),
        bufferSize: _bufferSize,
      );
      final result =
          await detector.getPitchFromIntBuffer(bytes);
      if (!_disposed && mounted && result.pitched) {
        final freq = result.pitch;
        if (freq > 50 && freq < 2000) {
          setState(() {
            _currentPitch = freq;
            _detectedNote = _getNoteName(freq);
            _cents = _getCents(freq);
          });
        }
      }
    } catch (e) {
      // Silently handle
    }
  }

  Future<void> _stopListening() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    _buffer.clear();
    if (!_disposed && mounted) {
      setState(() {
        _isListening = false;
        _currentPitch = 0.0;
        _detectedNote = '--';
        _cents = 0.0;
      });
    }
  }

  String _getNoteName(double frequency) {
    if (frequency <= 0) return '--';
    final semitonesFromA4 =
        (12 * (math.log(frequency / 440.0) / math.log(2)))
            .round();
    final noteIndex = ((semitonesFromA4 % 12) + 12) % 12;
    final octave = ((semitonesFromA4 + 9) ~/ 12) + 4;
    return '${_noteNames[noteIndex]}$octave';
  }

  double _getCents(double frequency) {
    if (frequency <= 0) return 0;
    final semitonesFromA4 =
        12 * (math.log(frequency / 440.0) / math.log(2));
    final nearestSemitone = semitonesFromA4.round();
    return (semitonesFromA4 - nearestSemitone) * 100;
  }

  Color _getTuningColor() {
    if (_detectedNote == '--') return Colors.grey;
    final absCents = _cents.abs();
    if (absCents < 5) return Colors.green;
    if (absCents < 15) return Colors.orange;
    return Colors.red;
  }

  String _getTuningStatus() {
    if (!_isListening) return 'Tap Start Tuner';
    if (_detectedNote == '--') return 'Play a note...';
    final absCents = _cents.abs();
    if (absCents < 5) return 'In Tune! ✓';
    if (_cents > 0) return 'Too Sharp — tune down ↓';
    return 'Too Flat — tune up ↑';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tuningColor = _getTuningColor();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuner',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        child: Column(
          children: [

            // --- Note Display ---
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: tuningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: tuningColor.withOpacity(0.4),
                    width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    _detectedNote,
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      color: tuningColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentPitch > 0
                        ? '${_currentPitch.toStringAsFixed(1)} Hz'
                        : '',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getTuningStatus(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tuningColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Cents Meter ---
            Column(
              children: [
                Text(
                  'Tuning Meter',
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface
                        .withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface
                            .withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 30,
                      color: Colors.green,
                    ),
                    Align(
                      alignment: Alignment(
                          (_cents / 50).clamp(-1.0, 1.0),
                          0),
                      child: Container(
                        width: 16,
                        height: 28,
                        decoration: BoxDecoration(
                          color: tuningColor,
                          borderRadius:
                              BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Flat',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface
                                .withOpacity(0.5))),
                    const Text('In Tune',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green)),
                    Text('Sharp',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface
                                .withOpacity(0.5))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // --- Start/Stop Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isListening
                    ? _stopListening
                    : _startListening,
                icon: Icon(
                    _isListening
                        ? Icons.mic_off
                        : Icons.mic,
                    size: 28),
                label: Text(
                  _isListening
                      ? 'Stop Tuner'
                      : 'Start Tuner',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening
                      ? Colors.red
                      : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isListening)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.green.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mic,
                        color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Microphone active — play a note!',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.green),
                    ),
                  ],
                ),
              ),
            if (!_isListening)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hold instrument close to mic and play one note at a time.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),

            // --- Reference Notes ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Common Reference Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ...(_referenceNotes.entries.map((entry) {
              final isDetected = _detectedNote
                  .startsWith(entry.key.split(' ')[0]);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDetected
                      ? Colors.green.withOpacity(0.15)
                      : colorScheme.onSurface
                          .withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDetected
                        ? Colors.green
                        : colorScheme.onSurface
                            .withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color:
                            isDetected ? Colors.green : null,
                      ),
                    ),
                    Text(
                      '${entry.value.toStringAsFixed(2)} Hz',
                      style: TextStyle(
                        color: isDetected
                            ? Colors.green
                            : colorScheme.onSurface
                                .withOpacity(0.5),
                      ),
                    ),
                    if (isDetected)
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }
}