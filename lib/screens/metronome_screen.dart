import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../metronome_service.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final _metronomeService = MetronomeService();
  final TextEditingController _bpmController =
      TextEditingController(text: '120');
  final List<DateTime> _tapTimes = [];
  final FocusNode _bpmFocusNode = FocusNode();
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _bpmController.text = '${_metronomeService.bpm}';
    _metronomeService.addListener(_onMetronomeUpdate);
    _bpmFocusNode.addListener(() {
      setState(() => _keyboardVisible = _bpmFocusNode.hasFocus);
    });
  }

  void _onMetronomeUpdate() {
    if (mounted) setState(() {});
  }

  void _dismissKeyboard() {
    final newBpm =
        int.tryParse(_bpmController.text) ?? _metronomeService.bpm;
    _metronomeService.updateBpm(newBpm);
    _bpmFocusNode.unfocus();
  }

  @override
  void dispose() {
    _metronomeService.removeListener(_onMetronomeUpdate);
    _bpmController.dispose();
    _bpmFocusNode.dispose();
    super.dispose();
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
      final newBpm = (60000 / avg).round().clamp(40, 240);
      _metronomeService.updateBpm(newBpm);
      setState(() => _bpmController.text = '$newBpm');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaying = _metronomeService.isPlaying;
    final bpm = _metronomeService.bpm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metronome',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: GestureDetector(
        onTap: _dismissKeyboard,
        child: Column(
          children: [
            // Done toolbar above keyboard
            if (_keyboardVisible)
              Container(
                color: Colors.grey.shade200,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _dismissKeyboard,
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(20, 20, 20, 48),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // --- BPM Display ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color:
                            Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.deepPurple
                                .withOpacity(0.3)),
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
                              focusNode: _bpmFocusNode,
                              keyboardType:
                                  TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 80,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration:
                                  const InputDecoration(
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.zero,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter
                                    .digitsOnly,
                                LengthLimitingTextInputFormatter(
                                    3),
                              ],
                              onChanged: (val) {
                                final newBpm =
                                    int.tryParse(val);
                                if (newBpm != null &&
                                    newBpm >= 40 &&
                                    newBpm <= 240) {
                                  setState(() =>
                                      _metronomeService
                                          .bpm = newBpm);
                                }
                              },
                              onSubmitted: (val) {
                                _dismissKeyboard();
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
                            value: bpm.toDouble(),
                            min: 40,
                            max: 240,
                            divisions: 200,
                            label: '$bpm BPM',
                            activeColor: Colors.deepPurple,
                            onChanged: (value) {
                              setState(() {
                                _bpmController.text =
                                    '${value.round()}';
                                _metronomeService.bpm =
                                    value.round();
                              });
                            },
                            onChangeEnd: (value) {
                              _metronomeService
                                  .updateBpm(value.round());
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
                        onPressed: isPlaying
                            ? _metronomeService.stop
                            : _metronomeService.start,
                        icon: Icon(
                          isPlaying
                              ? Icons.stop
                              : Icons.play_arrow,
                          size: 36,
                        ),
                        label: Text(
                          isPlaying ? 'Stop' : 'Start',
                          style:
                              const TextStyle(fontSize: 24),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPlaying
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
                              color: Colors.deepPurple,
                              width: 2),
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
          ],
        ),
      ),
    );
  }
}