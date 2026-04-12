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
  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  final List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

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

  Uint8List _generateTone(double frequency, {int durationMs = 2000}) {
    final numSamples = (_sampleRate * durationMs / 1000).round();
    final samples = Int16List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      final t = i / _sampleRate;
      double envelope = 1.0;
      final fadeLen = (_sampleRate * 0.01).round();
      if (i < fadeLen) {
        envelope = i / fadeLen;
      } else if (i > numSamples - fadeLen) {
        envelope = (numSamples - i) / fadeLen;
      }
      samples[i] =
          (math.sin(2 * math.pi * frequency * t) * 32767 * 0.5 * envelope)
              .round()
              .clamp(-32768, 32767);
    }
    final dataSize = numSamples * 2;
    final header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49);
    header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41);
    header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64); header.setUint8(37, 0x61);
    header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);
    final wav = Uint8List(44 + dataSize);
    wav.setAll(0, header.buffer.asUint8List());
    wav.setAll(44, samples.buffer.asUint8List());
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
    await _stopTone();
    try {
      final hasPermission = await _recorder.hasPermission();
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _processBuffer() async {
    if (_disposed) return;
    try {
      final bytes =
          Uint8List.fromList(_buffer.take(_bufferSize * 2).toList());
      final detector = PitchDetector(
        audioSampleRate: _sampleRate.toDouble(),
        bufferSize: _bufferSize,
      );
      final result = await detector.getPitchFromIntBuffer(bytes);
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
    } catch (e) {}
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
        (12 * (math.log(frequency / 440.0) / math.log(2))).round();
    final noteIndex = ((semitonesFromA4 % 12) + 12) % 12;
    final octave = ((semitonesFromA4 + 57) ~/ 12);
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
    if (_detectedNote == '--') return const Color(0xFF9B59B6);
    final absCents = _cents.abs();
    if (absCents < 5) return const Color(0xFF4CAF50);
    if (absCents < 15) return Colors.orange;
    return Colors.red;
  }

  String _getTuningStatus() {
    if (!_isListening) return 'Tap Start Tuner';
    if (_detectedNote == '--') return 'Play a note...';
    final absCents = _cents.abs();
    if (absCents < 5) return 'In Tune! ✓';
    if (_cents > 0) return 'Too Sharp ↓';
    return 'Too Flat ↑';
  }

  @override
  Widget build(BuildContext context) {
    final tuningColor = _getTuningColor();
    final isInTune = _detectedNote != '--' && _cents.abs() < 5;

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Tuner',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_purple, Color(0xFF9B59B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
        child: Column(
          children: [

            // --- Note Display Card ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isInTune
                      ? [
                          const Color(0xFF004D40),
                          const Color(0xFF00695C),
                        ]
                      : [_cardBg, _cardBg2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: tuningColor.withOpacity(0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tuningColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _detectedNote,
                    style: TextStyle(
                      fontSize: 90,
                      fontWeight: FontWeight.w900,
                      color: tuningColor,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentPitch > 0
                        ? '${_currentPitch.toStringAsFixed(1)} Hz'
                        : '',
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: tuningColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getTuningStatus(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tuningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Cents Meter ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_cardBg, _cardBg2]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _purple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Tuning Meter',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Container(
                          width: 2,
                          height: 32,
                          color: const Color(0xFF4CAF50)),
                      Align(
                        alignment: Alignment(
                            (_cents / 50).clamp(-1.0, 1.0), 0),
                        child: Container(
                          width: 14,
                          height: 28,
                          decoration: BoxDecoration(
                            color: tuningColor,
                            borderRadius:
                                BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    tuningColor.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Flat',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white38)),
                      Text('In Tune',
                          style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold)),
                      Text('Sharp',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white38)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Start/Stop Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isListening
                    ? _stopListening
                    : _startListening,
                icon: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    size: 24),
                label: Text(
                  _isListening ? 'Stop Tuner' : 'Start Tuner',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isListening
                      ? const Color(0xFFFF4444)
                      : const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                  shadowColor: _isListening
                      ? Colors.red.withOpacity(0.4)
                      : Colors.green.withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Status banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isListening
                      ? [
                          const Color(0xFF1B5E20),
                          const Color(0xFF2E7D32),
                        ]
                      : [_cardBg, _cardBg2],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isListening
                      ? Colors.green.withOpacity(0.5)
                      : _purple.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isListening
                        ? Icons.mic
                        : Icons.info_outline,
                    color: _isListening
                        ? Colors.greenAccent
                        : const Color(0xFF9B59B6),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isListening
                          ? 'Microphone active — play a note!'
                          : 'Hold instrument close to mic and play one note at a time.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isListening
                            ? Colors.greenAccent
                            : Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // --- Tone Generator ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tone Generator',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_playingNote != null)
                  GestureDetector(
                    onTap: _stopTone,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.stop,
                              size: 14, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Stop',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap a note to hear it — tune your instrument to match',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 14),

            // Chromatic keyboard grid
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: _toneNotes.map((note) {
                final isPlaying = _playingNote == note['name'];
                final isSharp =
                    (note['label'] as String).contains('#');
                return GestureDetector(
                  onTap: () => _playTone(
                      note['name'] as String,
                      note['freq'] as double),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isPlaying
                          ? const LinearGradient(
                              colors: [_purple, Color(0xFF9B59B6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: isSharp
                                  ? [
                                      Colors.white
                                          .withOpacity(0.1),
                                      Colors.white
                                          .withOpacity(0.05),
                                    ]
                                  : [_cardBg, _cardBg2],
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPlaying
                            ? _purple
                            : _purple.withOpacity(0.25),
                        width: isPlaying ? 1.5 : 1,
                      ),
                      boxShadow: isPlaying
                          ? [
                              BoxShadow(
                                color: _purple.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isPlaying)
                          const Icon(Icons.volume_up,
                              size: 12, color: Colors.white),
                        Text(
                          note['label'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isPlaying
                                ? Colors.white
                                : isSharp
                                    ? Colors.white70
                                    : Colors.white,
                          ),
                        ),
                        Text(
                          '${(note['freq'] as double).round()} Hz',
                          style: TextStyle(
                            fontSize: 8,
                            color: isPlaying
                                ? Colors.white60
                                : Colors.white30,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // --- Reference Notes ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Common Reference Notes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                  gradient: isDetected
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF1B5E20),
                            Color(0xFF2E7D32),
                          ],
                        )
                      : const LinearGradient(
                          colors: [_cardBg, _cardBg2]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDetected
                        ? Colors.green.withOpacity(0.6)
                        : _purple.withOpacity(0.2),
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
                        fontSize: 14,
                        color: isDetected
                            ? Colors.white
                            : Colors.white70,
                      ),
                    ),
                    Text(
                      '${entry.value.toStringAsFixed(2)} Hz',
                      style: TextStyle(
                        color: isDetected
                            ? Colors.white70
                            : Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                    if (isDetected)
                      const Icon(Icons.check_circle,
                          color: Colors.greenAccent, size: 18),
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