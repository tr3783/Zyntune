import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionCardSharer {
  static Future<void> shareSession({
    required BuildContext context,
    required int minutes,
    required String piece,
    required String instrument,
    required int currentStreak,
    required String date,
  }) async {
    final controller = ScreenshotController();
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'Musician';

    final card = SessionCard(
      minutes: minutes,
      piece: piece,
      instrument: instrument,
      currentStreak: currentStreak,
      date: date,
      userName: userName,
    );

    try {
      final Uint8List imageBytes = await controller.captureFromWidget(
        card,
        pixelRatio: 3.0,
        context: context,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zyntune_session.png');
      await file.writeAsBytes(imageBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '$minutes ${minutes == 1 ? 'minute' : 'minutes'} practice session with Zyntune 🎵',
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
    }
  }
}

class SessionCard extends StatelessWidget {
  final int minutes;
  final String piece;
  final String instrument;
  final int currentStreak;
  final String date;
  final String userName;

  const SessionCard({
    super.key,
    required this.minutes,
    required this.piece,
    required this.instrument,
    required this.currentStreak,
    required this.date,
    required this.userName,
  });

  String _formatDate(String raw) {
    const months = [
      'Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'Jun.',
      'Jul.', 'Aug.', 'Sep.', 'Oct.', 'Nov.', 'Dec.'
    ];
    try {
      final dt = DateTime.parse(raw.substring(0, 10));
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  String _motivationalMessage() {
    if (minutes >= 60) return 'Marathon session! 🏆';
    if (minutes >= 45) return 'Crushing it! 💪';
    if (minutes >= 30) return 'Solid practice! 🎯';
    if (minutes >= 20) return 'Keep it up! 🔥';
    return 'Every minute counts! 🎵';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0D1A), Color(0xFF1A0A4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Zyntune',
                style: TextStyle(
                  color: Color(0xFF9B59B6),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                _formatDate(date),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Practice time — big and bold
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$minutes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12, left: 6),
                child: Text(
                  'minute',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Text(
            _motivationalMessage(),
            style: const TextStyle(
              color: Color(0xFF6B21FF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.08),
          ),
          const SizedBox(height: 20),

          // Details row
          if (piece.isNotEmpty) ...[
            _DetailRow(icon: '🎵', label: piece),
            const SizedBox(height: 10),
          ],
          if (instrument.isNotEmpty) ...[
            _DetailRow(icon: '🎸', label: instrument),
            const SizedBox(height: 10),
          ],
          _DetailRow(icon: '🔥', label: '$currentStreak day streak'),
          const SizedBox(height: 20),

          // Footer
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.08),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'zyntune.app',
                style: TextStyle(
                  color: Color(0xFF6B21FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}