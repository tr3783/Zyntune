import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerService extends ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  Timer? _timer;
  int elapsed = 0;
  bool isRunning = false;
  bool isPaused = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed++;
      notifyListeners();
    });
    isRunning = true;
    isPaused = false;
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    isRunning = false;
    isPaused = true;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    elapsed = 0;
    isRunning = false;
    isPaused = false;
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    isRunning = false;
    isPaused = false;
    notifyListeners();
  }
}