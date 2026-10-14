import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../date_format.dart';

/// Shows the student's latest teacher reminder on the home screen, so it's
/// seen even if they missed or turned off the push notification.
class TeacherReminderCard extends StatefulWidget {
  const TeacherReminderCard({super.key});

  @override
  State<TeacherReminderCard> createState() => _TeacherReminderCardState();
}

class _TeacherReminderCardState extends State<TeacherReminderCard> {
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _teal = Color(0xFF00BFA5);

  // Reminders older than this aren't shown.
  static const _maxAge = Duration(days: 7);
  // Backed up per account by AccountDataService.
  static const _dismissedKey = 'dismissedReminderId';

  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String? _dismissedId;

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      _stream = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('reminders')
          .orderBy('sentAt', descending: true).limit(1)
          .snapshots();
    }
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _dismissedId = prefs.getString(_dismissedKey));
    });
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissedId = id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, id);
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final doc = docs.first;
        final data = doc.data();
        final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
        if (doc.id == _dismissedId || sentAt == null || DateTime.now().difference(sentAt) > _maxAge) {
          return const SizedBox.shrink();
        }
        final message = data['message'] as String? ?? '';
        final teacherName = data['teacherName'] as String? ?? 'Your teacher';

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _teal.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: _teal.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _teal.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Text('👋', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('From your teacher', style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text('$teacherName · ${formatFullDate(sentAt)}', style: const TextStyle(color: _teal, fontSize: 12)),
              ]),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close, color: Colors.white38, size: 18),
              onPressed: () => _dismiss(doc.id),
            ),
          ]),
        );
      },
    );
  }
}
