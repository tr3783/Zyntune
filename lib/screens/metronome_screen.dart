import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../metronome_service.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen>
    with SingleTickerProviderStateMixin {
  final _metronomeService = MetronomeService();
  final TextEditingController _bpmController =
      TextEditingController(text: '120');
  final List<DateTime> _tapTimes = [];
  final FocusNode _bpmFocusNode = FocusNode();
  bool _keyboardVisible = false;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  static const List<Map<String, dynamic>> _presets = [
    {'label': '60', 'bpm': 60},
    {'label': '80', 'bpm': 80},
    {'label': '100', 'bpm': 100},
    {'label': '120', 'bpm': 120},
    {'label': '140', 'bpm': 140},
    {'label': '160', 'bpm': 160},
  ];

  @override
  void initState() {
    super.initState();
    _bpmController.text = '${_metronomeService.bpm}';
    _metronomeService.addListener(_onMetronomeUpdate);
    _bpmFocusNode.addListener(() {
      setState(() => _keyboardVisible = _bpmFocusNode.hasFocus);
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeOut),
    );
  }

  void _onMetronomeUpdate() {
    if (mounted) {
      setState(() {});
      if (_metronomeService.isPlaying) {
        _pulseController?.forward().then((_) => _pulseController?.reverse());
      }
    }
  }

  void _dismissKeyboard() {
    final newBpm = int.tryParse(_bpmController.text) ?? _metronomeService.bpm;
    _metronomeService.updateBpm(newBpm);
    _bpmFocusNode.unfocus();
  }

  @override
  void dispose() {
    _metronomeService.removeListener(_onMetronomeUpdate);
    _bpmController.dispose();
    _bpmFocusNode.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  void _tapTempo() {
    final now = DateTime.now();
    _tapTimes.add(now);
    if (_tapTimes.length > 4) _tapTimes.removeAt(0);
    if (_tapTimes.length >= 2) {
      final intervals = <int>[];
      for (int i = 1; i < _tapTimes.length; i++) {
        intervals.add(
            _tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds);
      }
      final avg = intervals.reduce((a, b) => a + b) / intervals.length;
      final newBpm = (60000 / avg).round().clamp(40, 240);
      _metronomeService.updateBpm(newBpm);
      setState(() => _bpmController.text = '$newBpm');
    }
  }

  String _getTempoName(int bpm) {
    if (bpm < 60) return 'Largo';
    if (bpm < 66) return 'Larghetto';
    if (bpm < 76) return 'Adagio';
    if (bpm < 108) return 'Andante';
    if (bpm < 120) return 'Moderato';
    if (bpm < 156) return 'Allegro';
    if (bpm < 176) return 'Vivace';
    if (bpm < 200) return 'Presto';
    return 'Prestissimo';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaying = _metronomeService.isPlaying;
    final bpm = _metronomeService.bpm;
    final tempoName = _getTempoName(bpm);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Metronome',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6B21FF), Color(0xFF9B59B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: _dismissKeyboard,
        child: Column(
          children: [
            if (_keyboardVisible)
              Container(
                color: Colors.grey.shade900,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _dismissKeyboard,
                      child: const Text('Done',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B21FF))),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                child: Column(
                  children: [

                    // --- Beat Pulse Indicator ---
                    ScaleTransition(
                      scale: _pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isPlaying
                                ? [
                                    const Color(0xFF6B21FF),
                                    const Color(0xFF9B59B6),
                                  ]
                                : [
                                    const Color(0xFF1A0A4E),
                                    const Color(0xFF2D1B69),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: isPlaying
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF6B21FF)
                                        .withOpacity(0.5),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.music_note
                              : Icons.music_note_outlined,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPlaying ? 'Playing' : 'Ready',
                      style: TextStyle(
                        color: isPlaying
                            ? const Color(0xFF6B21FF)
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- BPM Display Card ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 28, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A0A4E), Color(0xFF2D1B69)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFF6B21FF).withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B21FF).withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'B P M',
                            style: TextStyle(
                              fontSize: 14,
                              letterSpacing: 6,
                              color: Color(0xFF9B59B6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 180,
                            child: TextField(
                              controller: _bpmController,
                              focusNode: _bpmFocusNode,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 88,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              onChanged: (val) {
                                final newBpm = int.tryParse(val);
                                if (newBpm != null &&
                                    newBpm >= 40 &&
                                    newBpm <= 240) {
                                  setState(
                                      () => _metronomeService.bpm = newBpm);
                                }
                              },
                              onSubmitted: (_) => _dismissKeyboard(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B21FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tempoName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9B59B6),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap number to type  •  40–240',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Quick Presets ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _presets.map((preset) {
                        final isSelected = bpm == preset['bpm'];
                        return GestureDetector(
                          onTap: () {
                            _metronomeService.updateBpm(preset['bpm']);
                            setState(() => _bpmController.text =
                                '${preset['bpm']}');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF6B21FF),
                                        Color(0xFF9B59B6)
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : const Color(0xFF1A0A4E),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : const Color(0xFF6B21FF)
                                        .withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${preset['label']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF9B59B6),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // --- BPM Slider ---
                    Row(
                      children: [
                        const Text('40',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF6B21FF),
                              inactiveTrackColor:
                                  const Color(0xFF6B21FF).withOpacity(0.2),
                              thumbColor: Colors.white,
                              overlayColor:
                                  const Color(0xFF6B21FF).withOpacity(0.2),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 10),
                            ),
                            child: Slider(
                              value: bpm.toDouble(),
                              min: 40,
                              max: 240,
                              divisions: 200,
                              label: '$bpm BPM',
                              onChanged: (value) {
                                setState(() {
                                  _bpmController.text = '${value.round()}';
                                  _metronomeService.bpm = value.round();
                                });
                              },
                              onChangeEnd: (value) {
                                _metronomeService.updateBpm(value.round());
                              },
                            ),
                          ),
                        ),
                        const Text('240',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- Play/Stop Button ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isPlaying
                            ? _metronomeService.stop
                            : _metronomeService.start,
                        icon: Icon(
                          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          size: 32,
                        ),
                        label: Text(
                          isPlaying ? 'Stop' : 'Start',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPlaying
                              ? const Color(0xFFFF4444)
                              : const Color(0xFF6B21FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: isPlaying ? 8 : 4,
                          shadowColor: isPlaying
                              ? Colors.red.withOpacity(0.4)
                              : const Color(0xFF6B21FF).withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // --- Tap Tempo ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _tapTempo,
                        icon: const Icon(Icons.touch_app_rounded, size: 22),
                        label: const Text('Tap Tempo',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A0A4E),
                          foregroundColor: const Color(0xFF9B59B6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(
                                color: Color(0xFF6B21FF), width: 1.5),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}