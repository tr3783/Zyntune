import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'review_helper.dart';

class StreakHelper {
  static const int pointsPerSession = 10;
  static const int freezeCost = 50;

  static Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateString(DateTime.now());
    final lastPractice = prefs.getString('lastPracticeDate') ?? '';
    final currentStreak = prefs.getInt('currentStreak') ?? 0;
    final longestStreak = prefs.getInt('longestStreak') ?? 0;
    final points = prefs.getInt('practicePoints') ?? 0;

    await prefs.setInt('practicePoints', points + pointsPerSession);

    if (lastPractice == today) return;

    final yesterday = _dateString(DateTime.now().subtract(const Duration(days: 1)));

    int newStreak;
    if (lastPractice == yesterday) {
      newStreak = currentStreak + 1;
    } else if (lastPractice.isNotEmpty && lastPractice != today) {
      final freezeActive = prefs.getBool('streakFreezeActive') ?? false;
      final twoDaysAgo = _dateString(DateTime.now().subtract(const Duration(days: 2)));
      if (freezeActive && lastPractice == twoDaysAgo) {
        newStreak = currentStreak + 1;
        await prefs.setBool('streakFreezeActive', false);
        await prefs.setString('streakFreezeUsedDate', today);
      } else {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    final newLongest = newStreak > longestStreak ? newStreak : longestStreak;
    await prefs.setString('lastPracticeDate', today);
    await prefs.setInt('currentStreak', newStreak);
    await prefs.setInt('longestStreak', newLongest);

    // Haptic on streak increase
    if (newStreak > currentStreak) {
      // Milestone streaks get a stronger celebration
      if (newStreak == 3 || newStreak == 7 || newStreak == 14 ||
          newStreak == 30 || newStreak == 60 || newStreak == 100) {
        await HapticFeedback.vibrate();
      } else {
        await HapticFeedback.heavyImpact();
      }
    }

    await ReviewHelper.maybeRequestReviewAfterStreak(newStreak);
  }

  static Future<bool> activateFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final points = prefs.getInt('practicePoints') ?? 0;
    final alreadyActive = prefs.getBool('streakFreezeActive') ?? false;
    if (alreadyActive) return false;
    if (points < freezeCost) return false;
    await prefs.setInt('practicePoints', points - freezeCost);
    await prefs.setBool('streakFreezeActive', true);
    return true;
  }

  static Future<Map<String, dynamic>> getStreakData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'currentStreak': prefs.getInt('currentStreak') ?? 0,
      'longestStreak': prefs.getInt('longestStreak') ?? 0,
      'practicePoints': prefs.getInt('practicePoints') ?? 0,
      'streakFreezeActive': prefs.getBool('streakFreezeActive') ?? false,
    };
  }

  static String _dateString(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}