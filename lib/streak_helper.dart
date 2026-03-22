import 'package:shared_preferences/shared_preferences.dart';

class StreakHelper {
  // Call this every time a practice session is saved
  static Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateString(DateTime.now());
    final lastPractice = prefs.getString('lastPracticeDate') ?? '';
    final currentStreak = prefs.getInt('currentStreak') ?? 0;
    final longestStreak = prefs.getInt('longestStreak') ?? 0;

    if (lastPractice == today) {
      // Already logged today, no change needed
      return;
    }

    final yesterday = _dateString(
        DateTime.now().subtract(const Duration(days: 1)));

    int newStreak;
    if (lastPractice == yesterday) {
      // Practiced yesterday — keep streak going!
      newStreak = currentStreak + 1;
    } else {
      // Missed a day — reset streak
      newStreak = 1;
    }

    final newLongest =
        newStreak > longestStreak ? newStreak : longestStreak;

    await prefs.setString('lastPracticeDate', today);
    await prefs.setInt('currentStreak', newStreak);
    await prefs.setInt('longestStreak', newLongest);
  }

  // Load current streak data
  static Future<Map<String, int>> getStreakData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'currentStreak': prefs.getInt('currentStreak') ?? 0,
      'longestStreak': prefs.getInt('longestStreak') ?? 0,
    };
  }

  // Format date as YYYY-MM-DD string
  static String _dateString(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}