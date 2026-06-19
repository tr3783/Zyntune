import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_helper.dart';

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
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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

  // Stores the DateTime when the countdown will finish (for background tracking)
  DateTime? _countdownEndTime;

  static const String _prefEndTime = 'countdown_end_time';
  static const String _prefTotal = 'countdown_total';
  static const int _countdownNotificationId = 999;

  VoidCallback? onCountdownFinished;

  /// Call this on app resume to resync countdown state
  Future<void> syncOnResume() async {
    // If a countdown is already active in memory, it's authoritative —
    // don't let stale persisted data overwrite it.
    if (_countdownEndTime != null) return;

    final prefs = await SharedPreferences.getInstance();
    final endTimeMs = prefs.getInt(_prefEndTime);
    final total = prefs.getInt(_prefTotal);

    if (endTimeMs == null || total == null) return;

    final endTime = DateTime.fromMillisecondsSinceEpoch(endTimeMs);
    final now = DateTime.now();
    final remaining = endTime.difference(now).inSeconds;

    countdownTotal = total;

    if (remaining <= 0) {
      // Finished while app was in background
      _countdownTimer?.cancel();
      countdownRemaining = 0;
      countdownActive = false;
      countdownFinished = true;
      _clearPersistedEndTime(prefs);
      HapticFeedback.heavyImpact();
      _playAlertSound();
      notifyListeners();
      Future.delayed(Duration.zero, () => onCountdownFinished?.call());
    } else {
      // Still running — resync remaining and restart tick
      countdownRemaining = remaining;
      countdownActive = true;
      countdownFinished = false;
      _countdownEndTime = endTime;
      notifyListeners();
      _startTicking();
    }
  }

  void startCountdown() {
    if (countdownRemaining <= 0) countdownRemaining = countdownTotal;

    _countdownTimer?.cancel();
    countdownActive = true;
    countdownFinished = false;

    // Record when the countdown will end
    _countdownEndTime = DateTime.now().add(Duration(seconds: countdownRemaining));
    _persistEndTime();

    // Schedule a local notification for when it finishes
    _scheduleCountdownNotification(countdownRemaining);

    notifyListeners();
    _startTicking();
  }

  void _startTicking() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownEndTime != null) {
        // Always calculate from end time to stay accurate
        final remaining = _countdownEndTime!.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          timer.cancel();
          countdownRemaining = 0;
          countdownActive = false;
          countdownFinished = true;
          _clearPersistedEndTime(null);
          HapticFeedback.heavyImpact();
          _playAlertSound();
          notifyListeners();
          Future.delayed(Duration.zero, () => onCountdownFinished?.call());
        } else {
          countdownRemaining = remaining;
          notifyListeners();
        }
      }
    });
  }

  Future<void> _scheduleCountdownNotification(int seconds) async {
    await NotificationHelper.scheduleCountdownFinished(
      id: _countdownNotificationId,
      secondsFromNow: seconds,
    );
  }

  Future<void> _cancelCountdownNotification() async {
    await NotificationHelper.cancelById(_countdownNotificationId);
  }

  Future<void> _persistEndTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefEndTime, _countdownEndTime!.millisecondsSinceEpoch);
    await prefs.setInt(_prefTotal, countdownTotal);
  }

  Future<void> _clearPersistedEndTime(SharedPreferences? prefs) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_prefEndTime);
    await p.remove(_prefTotal);
    _countdownEndTime = null;
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
    _countdownEndTime = null;
    _clearPersistedEndTime(null);
    _cancelCountdownNotification();
    notifyListeners();
  }

  void resetCountdown() {
    _countdownTimer?.cancel();
    countdownActive = false;
    countdownFinished = false;
    countdownRemaining = countdownTotal;
    _countdownEndTime = null;
    _clearPersistedEndTime(null);
    _cancelCountdownNotification();
    notifyListeners();
  }

  void setCountdownDuration(int minutes) {
    _countdownTimer?.cancel();
    countdownTotal = minutes * 60;
    countdownRemaining = countdownTotal;
    countdownActive = false;
    countdownFinished = false;
    _countdownEndTime = null;
    _clearPersistedEndTime(null);
    _cancelCountdownNotification();
    notifyListeners();
  }

  double get countdownProgress {
    if (countdownTotal == 0) return 0;
    return countdownRemaining / countdownTotal;
  }
}