import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const _appGroupId = 'group.com.topher.zyntune';
  static const _iOSWidgetName = 'ZyntuneWidget';

  /// Call this after saving a session, on app launch, and on app resume
  static Future<void> updateWidget() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      final prefs = await SharedPreferences.getInstance();

      // Get streak
      final currentStreak = prefs.getInt('currentStreak') ?? 0;

      // Get today's minutes
      final sessions = prefs.getStringList('practiceSessions') ?? [];
      final todayStr = DateTime.now().toString().substring(0, 10);
      int todayMinutes = 0;
      for (final s in sessions) {
        if (s.contains(todayStr)) {
          final match = RegExp(r'"durationMinutes":(\d+)').firstMatch(s);
          final mins = int.tryParse(match?.group(1) ?? '0') ?? 0;
          todayMinutes += mins;
        }
      }

      // Get user name
      final userName = prefs.getString('userName') ?? 'Musician';

      // Push to widget
      await HomeWidget.saveWidgetData<int>('currentStreak', currentStreak);
      await HomeWidget.saveWidgetData<int>('todayMinutes', todayMinutes);
      await HomeWidget.saveWidgetData<String>('userName', userName);

      // Reload the widget
      await HomeWidget.updateWidget(iOSName: _iOSWidgetName);
    } catch (e) {
      // Fail silently — widget is non-critical
    }
  }
}