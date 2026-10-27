import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntune/streak_helper.dart';

void main() {
  final now = DateTime(2026, 10, 27, 15);

  Future<int> streakWith(String lastPractice, {bool freeze = false, int saved = 12}) async {
    SharedPreferences.setMockInitialValues({
      'currentStreak': saved,
      'lastPracticeDate': lastPractice,
      'streakFreezeActive': freeze,
    });
    return StreakHelper.effectiveStreak(await SharedPreferences.getInstance(), now: now);
  }

  test('a streak is shown while it is still alive', () async {
    expect(await streakWith('2026-10-27'), 12); // practiced today
    expect(await streakWith('2026-10-26'), 12); // yesterday: can still keep it today
  });

  test('a broken streak shows 0 instead of the old number', () async {
    expect(await streakWith('2026-10-25'), 0);
    expect(await streakWith('2026-10-20'), 0);
  });

  test('an active Streak Freeze covers one missed day', () async {
    expect(await streakWith('2026-10-25', freeze: true), 12);
    expect(await streakWith('2026-10-24', freeze: true), 0);
  });

  test('works across a month boundary', () async {
    SharedPreferences.setMockInitialValues({'currentStreak': 5, 'lastPracticeDate': '2026-10-31'});
    final prefs = await SharedPreferences.getInstance();
    expect(StreakHelper.effectiveStreak(prefs, now: DateTime(2026, 11, 1)), 5);
    expect(StreakHelper.effectiveStreak(prefs, now: DateTime(2026, 11, 2)), 0);
  });
}
