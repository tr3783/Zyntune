import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class TimerService extends ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  final AudioPlayer _alertPlayer = AudioPlayer();

  // --- Stopwatch ---
  Timer? _stopwatchTimer;
  int elapsed = 0;
  bool isRunning = false;
  bool isPaused = false;

  void start() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed++;
      notifyListeners();
    });
    isRunning = true;
    isPaused = false;
    notifyListeners();
  }

  void pause() {
    _stopwatchTimer?.cancel();
    isRunning = false;
    isPaused = true;
    notifyListeners();
  }

  void reset() {
    _stopwatchTimer?.cancel();
    elapsed = 0;
    isRunning = false;
    isPaused = false;
    notifyListeners();
  }

  void stop() {
    _stopwatchTimer?.cancel();
    isRunning = false;
    isPaused = false;
    notifyListeners();
  }

  // --- Countdown ---
  Timer? _countdownTimer;
  int countdownTotal = 15 * 60;
  int countdownRemaining = 15 * 60;
  bool countdownActive = false;
  bool countdownFinished = false;
  VoidCallback? onCountdownFinished;

  void startCountdown() {
    if (countdownRemaining <= 0) {
      countdownRemaining = countdownTotal;
    }
    _countdownTimer?.cancel();
    countdownActive = true;
    countdownFinished = false;
    notifyListeners();

    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdownRemaining <= 1) {
        timer.cancel();
        countdownRemaining = 0;
        countdownActive = false;
        countdownFinished = true;
        // Vibrate
        HapticFeedback.heavyImpact();
        // Play alert sound 3 times
        _playAlertSound();
        notifyListeners();
        Future.delayed(Duration.zero, () {
          onCountdownFinished?.call();
        });
      } else {
        countdownRemaining--;
        notifyListeners();
      }
    });
  }

  Future<void> _playAlertSound() async {
    for (int i = 0; i < 3; i++) {
      await _alertPlayer.play(AssetSource('audio/alert.wav'));
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void pauseCountdown() {
    _countdownTimer?.cancel();
    countdownActive = false;
    notifyListeners();
  }

  void resetCountdown() {
    _countdownTimer?.cancel();
    countdownActive = false;
    countdownFinished = false;
    countdownRemaining = countdownTotal;
    notifyListeners();
  }

  void setCountdownDuration(int minutes) {
    _countdownTimer?.cancel();
    countdownTotal = minutes * 60;
    countdownRemaining = countdownTotal;
    countdownActive = false;
    countdownFinished = false;
    notifyListeners();
  }

  double get countdownProgress {
    if (countdownTotal == 0) return 0;
    return countdownRemaining / countdownTotal;
  }
}