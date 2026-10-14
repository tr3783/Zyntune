import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyntune/account_data_service.dart';

String session(String id, String date, {int minutes = 10}) =>
    jsonEncode({'id': id, 'date': date, 'durationMinutes': minutes, 'notes': '', 'instrument': 'Guitar', 'piece': ''});
String item(String id, String text) => jsonEncode({'id': id, 'text': text});

void main() {
  final service = AccountDataService();

  group('merge', () {
    test('combines lists from both sides instead of overwriting', () {
      final merged = service.mergeForTest(
        {'lessonNotes': [item('1', 'phone note')]},
        {'lessonNotes': [item('2', 'cloud note')]},
      );
      expect((merged['lessonNotes'] as List).length, 2);
    });

    test('phone version wins for the same item', () {
      final merged = service.mergeForTest(
        {'songs': [item('a', 'edited on phone')]},
        {'songs': [item('a', 'old cloud copy')]},
      );
      expect(merged['songs'], [item('a', 'edited on phone')]);
    });

    test('keeps the higher streak and points', () {
      final merged = service.mergeForTest(
        {'currentStreak': 3, 'longestStreak': 10, 'practicePoints': 50},
        {'currentStreak': 5, 'longestStreak': 8, 'practicePoints': 70},
      );
      expect(merged['currentStreak'], 5);
      expect(merged['longestStreak'], 10);
      expect(merged['practicePoints'], 70);
    });

    test('keeps values only one side has', () {
      final merged = service.mergeForTest({'userName': 'Joe'}, {'dailyGoalMinutes': 30});
      expect(merged, {'userName': 'Joe', 'dailyGoalMinutes': 30});
    });
  });

  group('sessions', () {
    test('merges by id and stores oldest first (the timer relies on this)', () {
      final merged = service.mergeSessionsForTest(
        [session('b', '2026-10-02 10:00'), session('c', '2026-10-03 10:00')],
        [session('a', '2026-10-01 10:00'), session('b', '2026-10-02 10:00')],
      );
      expect(merged.map((s) => jsonDecode(s)['id']).toList(), ['a', 'b', 'c']);
    });
  });

  group('accounts that only used older versions', () {
    test('recovers repertoire, goals and notes from older backups', () {
      final data = service.cloudAppDataForTest({
        'name': 'Joe',
        'instrument': 'Piano',
        'repertoire': [{'title': 'Fur Elise'}],
        'goals': [{'id': 'g1'}],
        'lessonNotes': [{'id': 'n1'}],
        'currentStreak': 4,
      });
      expect(data['userName'], 'Joe');
      expect(data['instruments'], ['Piano']);
      expect((data['songs'] as List).length, 1);
      expect((data['longTermGoals'] as List).length, 1);
      expect((data['lessonNotes'] as List).length, 1);
      expect(data['currentStreak'], 4);
      expect(data['onboardingComplete'], true);
    });

    test('uses the account data saved by 2.5.1+ when present', () {
      final data = service.cloudAppDataForTest({
        'name': 'Old name',
        'appData': {'userName': 'New name'},
      });
      expect(data, {'userName': 'New name'});
    });
  });

  group('parking (setting data aside for one account)', () {
    test('clears personal data from the phone but keeps device settings', () async {
      SharedPreferences.setMockInitialValues({
        'practiceSessions': [session('a', '2026-10-01 10:00')],
        'userName': 'Joe',
        'reminderHour': 9,
      });
      final prefs = await SharedPreferences.getInstance();
      await service.parkForTest(prefs, 'uid-joe');

      expect(prefs.getStringList('practiceSessions'), isNull);
      expect(prefs.getString('userName'), isNull);
      expect(prefs.getInt('reminderHour'), 9);
      expect(prefs.getString('parkedData_uid-joe'), isNotNull);
    });

    test('restores only for the same account, then removes the parked copy', () async {
      SharedPreferences.setMockInitialValues({
        'practiceSessions': [session('a', '2026-10-01 10:00')],
        'userName': 'Joe',
      });
      final prefs = await SharedPreferences.getInstance();
      await service.parkForTest(prefs, 'uid-joe');

      // Someone else restoring finds nothing of Joe's.
      await service.restoreParkedForTest(prefs, 'uid-amy');
      expect(prefs.getString('userName'), isNull);
      expect(prefs.getStringList('practiceSessions'), isNull);

      await service.restoreParkedForTest(prefs, 'uid-joe');
      expect(prefs.getString('userName'), 'Joe');
      expect(prefs.getStringList('practiceSessions')!.length, 1);
      expect(prefs.getString('parkedData_uid-joe'), isNull);
    });

    test('parking twice keeps both sets of data', () async {
      SharedPreferences.setMockInitialValues({
        'practiceSessions': [session('a', '2026-10-01 10:00')],
      });
      final prefs = await SharedPreferences.getInstance();
      await service.parkForTest(prefs, 'uid-joe');
      await prefs.setStringList('practiceSessions', [session('b', '2026-10-02 10:00')]);
      await service.parkForTest(prefs, 'uid-joe');

      await service.restoreParkedForTest(prefs, 'uid-joe');
      expect(prefs.getStringList('practiceSessions')!.length, 2);
    });
  });
}
