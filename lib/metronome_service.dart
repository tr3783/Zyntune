import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MetronomeService extends ChangeNotifier {
  static final MetronomeService _instance = MetronomeService._internal();
  factory MetronomeService() => _instance;
  MetronomeService._internal() {
    _setupChannel();
    _loadBpm();
  }

  // The last tempo is remembered on this device between launches.
  static const _bpmKey = 'metronomeBpm';

  Future<void> _loadBpm() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getInt(_bpmKey);
      if (saved != null && saved != bpm) {
        bpm = saved.clamp(40, 240);
        notifyListeners();
      }
    } catch (_) {}
  }

  static const _channel = MethodChannel('com.topher.zyntune/metronome');

  int bpm = 120;
  int subdivision = 1; // 1=quarter, 2=8th, 3=triplet, 4=16th
  bool isPlaying = false;

  void _setupChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onBeat') {
        if (isPlaying) notifyListeners();
      } else if (call.method == 'onStopped') {
        // iOS stopped the audio (phone call, headphones unplugged...).
        isPlaying = false;
        notifyListeners();
      }
    });
  }

  void start() async {
    isPlaying = true;
    notifyListeners();
    try {
      await _channel.invokeMethod('start', {
        'bpm': bpm.toDouble(),
        'subdivision': subdivision,
      });
    } catch (e) {
      debugPrint('MetronomeService start error: $e');
    }
  }

  void stop() async {
    isPlaying = false;
    notifyListeners();
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('MetronomeService stop error: $e');
    }
  }

  void updateBpm(int newBpm) async {
    bpm = newBpm.clamp(40, 240);
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) => prefs.setInt(_bpmKey, bpm)).catchError((_) => false);
    try {
      if (isPlaying) {
        await _channel.invokeMethod('updateBpm', bpm.toDouble());
      }
    } catch (e) {
      debugPrint('MetronomeService updateBpm error: $e');
    }
  }

  void updateSubdivision(int newSubdivision) async {
    subdivision = newSubdivision;
    notifyListeners();
    try {
      if (isPlaying) {
        await _channel.invokeMethod('updateSubdivision', subdivision);
      }
    } catch (e) {
      debugPrint('MetronomeService updateSubdivision error: $e');
    }
  }
}