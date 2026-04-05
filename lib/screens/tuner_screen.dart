import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  String? _playingNote;
  final AudioPlayer _tonePlayer = AudioPlayer();

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  final List<int> _buffer = [];

  static const int _sampleRate = 44100;
  static const int _bufferSize = 4096;

  final List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  // Full chromatic reference notes for tone generator
  final List<Map<String, dynamic>> _toneNotes = [
    {'name': 'C4', 'label': 'C', 'freq': 261.63},
    {'name': 'C#4', 'label': 'C#', 'freq': 277.18},
    {'name': 'D4', 'label': 'D', 'freq': 293.66},
    {'name': 'D#4', 'label': 'D#', 'freq': 311.13},
    {'name': 'E4', 'label': 'E', 'freq': 329.63},
    {'name': 'F4', 'label': 'F', 'freq': 349.23},
    {'name': 'F#4', 'label': 'F#', 'freq': 369.99},
    {'name': 'G4', 'label': 'G', 'freq': 392.00},
    {'name': 'G#4', 'label': 'G#', 'freq': 415.30},
    {'name': 'A4', 'label': 'A', 'freq': 440.00},
    {'name': 'A#4', 'label': 'A#', 'freq': 466.16},
    {'name': 'B4', 'label': 'B', 'freq': 493.88},
  ];

  // Common tuning references
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
    _tonePlayer.dispose();
    super.dispose();
  }

  // Generate a sine wave tone at given frequency
  Uint8List _generateTone(double frequency,
      {int durationMs = 2000}) {
    final numSamples =
        (_sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      // Fade in/out to avoid clicks
      double envelope = 1.0;
      final fadeLen = (_sampleRate * 0.01).round();
      if (i < fadeLen) {
        envelope = i / fadeLen;
      } else if (i > numSamples - fadeLen) {
        envelope = (numSamples - i) / fadeLen;
      }
      samples[i] =
          (math.sin(2 * math.pi * frequency * t) *
                  32767 *
                  0.5 *
                  envelope)
              .round()
              .clamp(-32768, 32767);
    }
    // Build WAV file bytes
    final dataSize = numSamples * 2;
    final header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // (space)
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(
        24, _sampleRate, Endian.little); // sample rate
    header.setUint32(
        28, _sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits/sample
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setAll(0, header.buffer.asUint8List());
    final sampleBytes = samples.buffer.asUint8List();
    wav.setAll(44, sampleBytes);
    return wav;
  }

  Future<void> _playTone(String noteName, double freq) async {
    if (_playingNote == noteName) {
      await _tonePlayer.stop();
      setState(() => _playingNote = null);
      return;
    }
    setState(() => _playingNote = noteName);
    await _tonePlayer.stop();
    try {
      final wav = _generateTone(freq, durationMs: 3000);
      // Write to temp file
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tone.wav');
      await file.writeAsBytes(wav);
      await _tonePlayer.setReleaseMode(ReleaseMode.loop);
      await _tonePlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing tone: $e')),
        );
      }
    }
  }

  Future<void> _stopTone() async {
    await _tonePlayer.stop();
    setState(() => _playingNote = null);
  }

  Future<void> _startListening() async {
    // Stop tone if playing
    await _stopTone();
    try {
      final hasPermission =
          await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Microphone permission denied. Go to Settings → Zyntune → Microphone.'),
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
    final noteIndex =
        ((semitonesFromA4 % 12) + 12) % 12;
    final octave =
        ((semitonesFromA4 + 9) ~/ 12) + 4;
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
        padding:
            const EdgeInsets.fromLTRB(20, 20, 20, 48),
        child: Column(
          children: [

            // --- Note Display ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: 32),
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
                        color: Colors.green),
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
            const SizedBox(height: 12),

            if (_isListening)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          Colors.green.withOpacity(0.3)),
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
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          Colors.blue.withOpacity(0.3)),
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

            // --- Tone Generator ---
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tone Generator',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                if (_playingNote != null)
                  TextButton.icon(
                    onPressed: _stopTone,
                    icon: const Icon(Icons.stop,
                        size: 16),
                    label: const Text('Stop'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a note to hear it — tune your instrument to match',
              style: TextStyle(
                fontSize: 12,
                color:
                    colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),

            // Chromatic keyboard grid
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: _toneNotes.map((note) {
                final isPlaying =
                    _playingNote == note['name'];
                final isSharp =
                    (note['label'] as String).contains('#');
                return GestureDetector(
                  onTap: () => _playTone(
                      note['name'] as String,
                      note['freq'] as double),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? Colors.deepPurple
                          : isSharp
                              ? colorScheme.onSurface
                                  .withOpacity(0.15)
                              : Colors.deepPurple
                                  .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                        color: isPlaying
                            ? Colors.deepPurple
                            : Colors.deepPurple
                                .withOpacity(0.3),
                        width: isPlaying ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        if (isPlaying)
                          const Icon(Icons.volume_up,
                              size: 14,
                              color: Colors.white),
                        Text(
                          note['label'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isPlaying
                                ? Colors.white
                                : colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${(note['freq'] as double).round()} Hz',
                          style: TextStyle(
                            fontSize: 8,
                            color: isPlaying
                                ? Colors.white70
                                : colorScheme.onSurface
                                    .withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

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
                  borderRadius:
                      BorderRadius.circular(12),
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
                        color: isDetected
                            ? Colors.green
                            : null,
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