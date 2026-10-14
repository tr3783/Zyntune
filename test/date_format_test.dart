import 'package:flutter_test/flutter_test.dart';
import 'package:zyntune/date_format.dart';

void main() {
  test('full date', () {
    expect(formatFullDate(DateTime(2026, 10, 14)), 'October 14, 2026');
    expect(formatFullDate(DateTime(2026, 1, 3)), 'January 3, 2026');
  });

  test('with weekday', () {
    expect(formatFullDateWithWeekday(DateTime(2026, 10, 14)), 'Wednesday, October 14, 2026');
  });

  test('stored dates in every shape the app saves', () {
    expect(formatStoredDate('2026-10-14'), 'October 14, 2026');
    expect(formatStoredDate('2026-10-14 09:30'), 'October 14, 2026');
    expect(formatStoredDate('2026-10-14 09:30:12.345'), 'October 14, 2026');
    expect(formatStoredDate('2026-10-4'), 'October 4, 2026');
  });

  test('leaves non-dates alone', () {
    expect(formatStoredDate(''), '');
    expect(formatStoredDate('someday'), 'someday');
  });
}
