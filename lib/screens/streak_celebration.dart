import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class StreakCelebration {
  static const List<int> _milestones = [3, 7, 14, 30, 60, 100];

  /// Call after updating streak — shows celebration if milestone hit
  static Future<void> maybeShow(BuildContext context, int newStreak) async {
    if (!_milestones.contains(newStreak)) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'streakCelebrated_$newStreak';
    if (prefs.getBool(key) ?? false) return;

    await prefs.setBool(key, true);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _StreakCelebrationDialog(streak: newStreak),
    );
  }
}

class _StreakCelebrationDialog extends StatefulWidget {
  final int streak;
  const _StreakCelebrationDialog({required this.streak});

  @override
  State<_StreakCelebrationDialog> createState() => _StreakCelebrationDialogState();
}

class _StreakCelebrationDialogState extends State<_StreakCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  String get _emoji {
    if (widget.streak >= 100) return '🏆';
    if (widget.streak >= 60) return '💎';
    if (widget.streak >= 30) return '🔥';
    if (widget.streak >= 14) return '⚡';
    if (widget.streak >= 7) return '🌟';
    return '🎯';
  }

  String get _title {
    if (widget.streak >= 100) return 'Century Streak!';
    if (widget.streak >= 60) return 'Two Month Streak!';
    if (widget.streak >= 30) return 'One Month Streak!';
    if (widget.streak >= 14) return 'Two Week Streak!';
    if (widget.streak >= 7) return 'One Week Streak!';
    return '3 Day Streak!';
  }

  String get _message {
    if (widget.streak >= 100) return 'Unbelievable dedication. You\'re a true musician.';
    if (widget.streak >= 60) return 'Two months of consistent practice. Incredible!';
    if (widget.streak >= 30) return 'A full month of daily practice. You\'re unstoppable!';
    if (widget.streak >= 14) return 'Two weeks straight! Your skills are growing fast.';
    if (widget.streak >= 7) return 'A full week! Consistency is the key to mastery.';
    return 'You\'re building a great habit. Keep it going!';
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
    _confettiController.play();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Confetti
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: pi / 2,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.05,
          numberOfParticles: 20,
          gravity: 0.2,
          colors: const [
            Color(0xFF6B21FF),
            Color(0xFF9B59B6),
            Color(0xFF00BFA5),
            Color(0xFFFF6B35),
            Color(0xFFFFD700),
            Colors.pink,
          ],
        ),

        // Dialog
        Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A0A4E), Color(0xFF2D1B69)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF6B21FF).withOpacity(0.6), width: 2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6B21FF).withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_emoji, style: const TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      '${widget.streak} Day Streak!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _title,
                      style: TextStyle(
                        color: const Color(0xFF9B59B6),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B21FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6B21FF).withOpacity(0.3)),
                      ),
                      child: Text(
                        _message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B21FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: const Color(0xFF6B21FF).withOpacity(0.4),
                        ),
                        child: const Text('Keep it up! 🔥', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}