import 'dart:async';
import 'dart:isolate';

// This runs in a completely separate thread
void metronomeIsolateEntry(SendPort sendPort) {
  final receivePort = ReceivePort();

  // Send our receive port back so main thread can talk to us
  sendPort.send(receivePort.sendPort);

  Timer? timer;
  int tickCount = 0;
  DateTime? startTime;
  int bpm = 120;
  int subdivision = 1;
  int beatsPerMeasure = 4;
  int currentBeat = 0;
  int currentSubdivision = 0;

  receivePort.listen((message) {
    if (message is Map) {
      final type = message['type'] as String;

      if (type == 'start') {
        bpm = message['bpm'] as int;
        subdivision = message['subdivision'] as int;
        beatsPerMeasure = message['beatsPerMeasure'] as int;
        tickCount = 0;
        currentBeat = 0;
        currentSubdivision = 0;
        startTime = DateTime.now();

        final intervalMs = 60000.0 / bpm / subdivision;

        // Poll every 2ms for maximum accuracy
        timer = Timer.periodic(
            const Duration(milliseconds: 2), (_) {
          final now = DateTime.now();
          final elapsed =
              now.difference(startTime!).inMicroseconds /
                  1000.0;
          final expectedTime = tickCount * intervalMs;

          if (elapsed >= expectedTime) {
            final isMainBeat = currentSubdivision == 0;
            final isFirstBeat =
                currentBeat == 0 && isMainBeat;

            // Send tick info back to UI thread
            sendPort.send({
              'type': 'tick',
              'isMainBeat': isMainBeat,
              'isFirstBeat': isFirstBeat,
              'currentBeat': currentBeat,
              'currentSubdivision': currentSubdivision,
            });

            // Advance counters
            currentSubdivision =
                (currentSubdivision + 1) % subdivision;
            if (currentSubdivision == 0) {
              if (beatsPerMeasure == 1) {
                currentBeat = 1;
              } else {
                currentBeat =
                    (currentBeat % beatsPerMeasure) + 1;
              }
            }
            tickCount++;
          }
        });

      } else if (type == 'stop') {
        timer?.cancel();
        timer = null;
        tickCount = 0;
        currentBeat = 0;
        currentSubdivision = 0;
      }
    }
  });
}