import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';

class ReviewHelper {
  static const _lastReviewPromptKey = 'lastReviewPromptDate';
  static const _hasReviewedKey = 'hasRequestedReview';

  /// Call after saving a session — triggers on 5th, 20th, 50th session
  static Future<void> maybeRequestReviewAfterSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = prefs.getStringList('practiceSessions') ?? [];
    final count = sessions.length;

    // Trigger on 5th, 20th, 50th session
    if (count != 5 && count != 20 && count != 50) return;

    await _requestReview(prefs);
  }

  /// Call after streak update — triggers on 3, 7, 14 day streaks
  static Future<void> maybeRequestReviewAfterStreak(int streak) async {
    if (streak != 3 && streak != 7 && streak != 14) return;

    final prefs = await SharedPreferences.getInstance();
    await _requestReview(prefs);
  }

  static Future<void> _requestReview(SharedPreferences prefs) async {
    // Don't prompt more than once every 60 days
    final lastPrompt = prefs.getString(_lastReviewPromptKey);
    if (lastPrompt != null) {
      final last = DateTime.tryParse(lastPrompt);
      if (last != null && DateTime.now().difference(last).inDays < 60) return;
    }

    try {
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setString(_lastReviewPromptKey, DateTime.now().toIso8601String());
        await prefs.setBool(_hasReviewedKey, true);
      }
    } catch (e) {
      // Fail silently — never crash over a review prompt
    }
  }
}