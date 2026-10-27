import 'package:flutter/material.dart';
import '../metronome_service.dart';

/// Start/stop the metronome and change the tempo without leaving the
/// recording screen (audio or video).
class MetronomeControl extends StatelessWidget {
  const MetronomeControl({super.key});

  @override
  Widget build(BuildContext context) {
    final metronome = MetronomeService();
    return ListenableBuilder(
      listenable: metronome,
      builder: (context, _) {
        Widget step(IconData icon, String tip, int delta) => IconButton(
              tooltip: tip,
              visualDensity: VisualDensity.compact,
              icon: Icon(icon, color: Colors.white, size: 20),
              onPressed: () => metronome.updateBpm(metronome.bpm + delta),
            );
        return Container(
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            step(Icons.remove, 'Slower', -1),
            TextButton.icon(
              onPressed: metronome.isPlaying ? metronome.stop : metronome.start,
              icon: Icon(metronome.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white),
              label: Text(
                '${metronome.bpm} BPM',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            step(Icons.add, 'Faster', 1),
          ]),
        );
      },
    );
  }
}
