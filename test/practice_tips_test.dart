import 'package:flutter_test/flutter_test.dart';
import 'package:zyntune/practice_tips.dart';

void main() {
  test('100 different tips', () {
    expect(practiceTips, hasLength(100));
    expect(practiceTips.toSet(), hasLength(100));
  });

  test('three different tips a day, and every tip shows within about a month', () {
    final seen = <String>{};
    for (var d = 0; d < 34; d++) {
      final tips = tipsForDay(DateTime(2026, 11, 1).add(Duration(days: d)));
      expect(tips.toSet(), hasLength(3));
      seen.addAll(tips);
    }
    expect(seen, hasLength(100));
  });

  test('the same day always shows the same tips', () {
    expect(tipsForDay(DateTime(2026, 10, 29, 8)), tipsForDay(DateTime(2026, 10, 29, 22)));
  });
}
