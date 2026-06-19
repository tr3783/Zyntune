import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../auth_service.dart';
import '../firestore_service.dart';
import 'assignment_screen.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  String? _teacherCode;
  bool _loadingCode = true;

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  void initState() {
    super.initState();
    _loadTeacherCode();
  }

  Future<void> _loadTeacherCode() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data?['teacherCode'] != null) {
      setState(() { _teacherCode = data!['teacherCode']; _loadingCode = false; });
    } else {
      final code = _generateCode(uid);
      await db.collection('users').doc(uid).update({'teacherCode': code});
      setState(() { _teacherCode = code; _loadingCode = false; });
    }
  }

  String _generateCode(String uid) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final hash = uid.hashCode.abs();
    String code = '';
    int n = hash;
    for (int i = 0; i < 6; i++) {
      code += chars[n % chars.length];
      n = (n ~/ chars.length) + uid.codeUnitAt(i % uid.length);
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Studio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Teacher Code Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Teacher Code', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _loadingCode
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(_teacherCode ?? '------', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4, fontFamily: 'monospace')),
                ),
                GestureDetector(
                  onTap: () {
                    if (_teacherCode != null) {
                      Clipboard.setData(ClipboardData(text: _teacherCode!));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
                    }
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.copy, color: Colors.white, size: 14), SizedBox(width: 6), Text('Copy', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))])),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_teacherCode != null) {
                      Share.share('Join my Zyntune studio! Download the app at https://zyntune.com and enter my teacher code: $_teacherCode', subject: 'Join my Zyntune Studio');
                    }
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.share, color: Colors.white, size: 14), SizedBox(width: 6), Text('Share', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))])),
                ),
              ]),
              const SizedBox(height: 12),
              const Text('Share this code with your students so they can link to your studio.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 28),

          // Students List
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('My Students', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            StreamBuilder<QuerySnapshot>(
              stream: uid != null ? FirebaseFirestore.instance.collection('users').where('teacherId', isEqualTo: uid).snapshots() : const Stream.empty(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return Text('$count students', style: const TextStyle(fontSize: 13, color: Color(0xFF9B59B6)));
              },
            ),
          ]),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: uid != null ? FirebaseFirestore.instance.collection('users').where('teacherId', isEqualTo: uid).snapshots() : const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF6B21FF)));
              final students = snapshot.data?.docs ?? [];
              if (students.isEmpty) {
                return Container(
                  width: double.infinity, padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.3))),
                  child: Column(children: [
                    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.people_outline, size: 36, color: Color(0xFF9B59B6))),
                    const SizedBox(height: 16),
                    const Text('No students yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Share your teacher code with students to get started.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4)),
                  ]),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final data = students[index].data() as Map<String, dynamic>;
                  final studentUid = students[index].id;
                  return _StudentCard(
                    data: data,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailScreen(studentUid: studentUid, studentData: data))),
                  );
                },
              );
            },
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STUDENT CARD
// ─────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _StudentCard({required this.data, required this.onTap});

  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? 'Student';
    final instrument = data['instrument'] as String? ?? '';
    final streak = data['currentStreak'] as int? ?? 0;
    final totalSessions = data['totalSessions'] as int? ?? 0;
    final totalMinutes = data['totalMinutes'] as int? ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.25))),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)]), shape: BoxShape.circle), child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            if (instrument.isNotEmpty) Text(instrument, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [const Text('🔥', style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text('$streak days', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))]),
            const SizedBox(height: 4),
            Text('$totalSessions sessions • ${totalMinutes}m', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STUDENT DETAIL SCREEN
// ─────────────────────────────────────────

class StudentDetailScreen extends StatefulWidget {
  final String studentUid;
  final Map<String, dynamic> studentData;
  const StudentDetailScreen({super.key, required this.studentUid, required this.studentData});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Map<String, dynamic> _studentData;
  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  void initState() {
    super.initState();
    _studentData = Map<String, dynamic>.from(widget.studentData);
  }

  DateTime? _latestAssignmentDate(List<Map<String, dynamic>> assignments) {
    if (assignments.isEmpty) return null;
    final ts = assignments.first['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  List<Map<String, dynamic>> _sessionsSince(List<Map<String, dynamic>> sessions, DateTime? since) {
    if (since == null) return sessions;
    return sessions.where((s) {
      try {
        final d = DateTime.parse((s['date'] as String).substring(0, 10));
        return !d.isBefore(DateTime(since.year, since.month, since.day));
      } catch (_) { return false; }
    }).toList();
  }

  Map<String, int> _pieceBreakdown(List<Map<String, dynamic>> sessions) {
    final Map<String, int> breakdown = {};
    for (final s in sessions) {
      final piece = (s['piece'] as String?)?.trim();
      final mins = s['durationMinutes'] as int? ?? 0;
      final label = (piece == null || piece.isEmpty) ? 'Free Practice' : piece;
      breakdown[label] = (breakdown[label] ?? 0) + mins;
    }
    return breakdown;
  }

  Map<String, int> _instrumentBreakdown(List<Map<String, dynamic>> sessions) {
    final Map<String, int> breakdown = {};
    for (final s in sessions) {
      final instrument = (s['instrument'] as String?)?.trim();
      final mins = s['durationMinutes'] as int? ?? 0;
      final label = (instrument == null || instrument.isEmpty) ? 'Other' : instrument;
      breakdown[label] = (breakdown[label] ?? 0) + mins;
    }
    return breakdown;
  }

  String _formatFullDate(DateTime dt) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatDate(String raw) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    try {
      final dt = DateTime.parse(raw.substring(0, 10));
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) { return raw; }
  }

  void _showReminderDialog(BuildContext context, String studentName) {
    final List<String> presets = [
      "Don't forget to practice today! 🎵",
      "Great work this week — keep it up! 🌟",
      "Lesson coming up — make sure you've practiced!",
      "Check your assignments in Zyntune!",
      "You're doing great — keep the streak going! 🔥",
    ];
    int? selectedIndex;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.notifications_active_outlined, color: _purple, size: 18)),
            const SizedBox(width: 10),
            const Text('Send Reminder', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choose a message to send to $studentName.', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 14),
            ...presets.asMap().entries.map((entry) => GestureDetector(
              onTap: () => setDialogState(() => selectedIndex = entry.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selectedIndex == entry.key ? _purple.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selectedIndex == entry.key ? _purple : Colors.white.withOpacity(0.1)),
                ),
                child: Text(entry.value, style: TextStyle(color: selectedIndex == entry.key ? Colors.white : Colors.white70, fontSize: 13)),
              ),
            )),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton.icon(
              onPressed: selectedIndex == null ? null : () async {
                final idx = selectedIndex!;
                Navigator.pop(ctx);
                try {
                  final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
                  await functions.httpsCallable('sendReminder').call({
                    'studentUid': widget.studentUid,
                    'presetIndex': idx,
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder sent to $studentName!'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reminder: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send'),
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, disabledBackgroundColor: _purple.withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDialog(String assignmentId, String existingFeedback, Map<String, dynamic> assignment) {
    final controller = TextEditingController(text: existingFeedback);
    final title = assignment['title'] as String? ?? '';
    final pieces = (assignment['pieces'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final checklist = (assignment['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final completedItems = checklist.where((i) => i['checked'] == true).length;
    final completed = assignment['completed'] as bool? ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(color: Color(0xFF1A0A4E), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Leave Feedback', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(completed ? Icons.check_circle : Icons.assignment_outlined, color: completed ? Colors.green : _purple, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                  if (completed) const Text('Completed', style: TextStyle(color: Colors.green, fontSize: 11)),
                ]),
                if (pieces.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...pieces.map((p) {
                    final pieceName = p['piece'] as String? ?? '';
                    final pieceChecklist = (p['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                    final doneItems = pieceChecklist.where((i) => i['checked'] == true).length;
                    if (pieceName.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        const Icon(Icons.music_note, color: Color(0xFFE91E8C), size: 12),
                        const SizedBox(width: 6),
                        Expanded(child: Text(pieceName, style: const TextStyle(color: Color(0xFFE91E8C), fontSize: 12))),
                        if (pieceChecklist.isNotEmpty) Text('$doneItems/${pieceChecklist.length}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ]),
                    );
                  }),
                ] else if (checklist.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('$completedItems / ${checklist.length} tasks completed', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: checklist.isEmpty ? 0 : completedItems / checklist.length, backgroundColor: Colors.white12, color: completed ? Colors.green : _purple, borderRadius: BorderRadius.circular(4)),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Great work on the left hand! Focus on dynamics in measure 8.',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple, width: 2)),
                fillColor: Colors.white.withOpacity(0.05),
                filled: true,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: () async {
                  final text = controller.text.trim();
                  Navigator.pop(ctx);
                  if (text.isNotEmpty) {
                    await FirestoreService().addFeedback(studentUid: widget.studentUid, assignmentId: assignmentId, feedback: text);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback sent!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send Feedback', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _studentData['name'] as String? ?? 'Student';
    final instrument = _studentData['instrument'] as String? ?? '';
    final streak = _studentData['currentStreak'] as int? ?? 0;
    final longestStreak = _studentData['longestStreak'] as int? ?? 0;
    final totalSessions = _studentData['totalSessions'] as int? ?? 0;
    final totalMinutes = _studentData['totalMinutes'] as int? ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final timeStr = hours > 0 ? (mins > 0 ? '${hours}h ${mins}m' : '${hours}h') : '${mins}m';
    final repertoire = (_studentData['repertoire'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _darkBg,
        appBar: AppBar(
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
          actions: [
            IconButton(
              onPressed: () => _showReminderDialog(context, name),
              icon: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 22),
              tooltip: 'Send Reminder',
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentScreen(studentUid: widget.studentUid, studentName: name))),
              icon: const Icon(Icons.assignment_add, color: Colors.white, size: 18),
              label: const Text('Assign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Sessions'),
              Tab(text: 'Assignments'),
            ],
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService().getStudentAssignments(widget.studentUid),
          builder: (context, assignmentSnapshot) {
            final assignments = assignmentSnapshot.data ?? [];
            final sinceDate = _latestAssignmentDate(assignments);

            return TabBarView(children: [

          // ── TAB 1: OVERVIEW ──
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService().getStudentSessions(widget.studentUid),
            builder: (context, sessionSnapshot) {
              final allSessions = sessionSnapshot.data ?? [];
              final recentSessions = _sessionsSince(allSessions, sinceDate);
              final recentMinutes = recentSessions.fold<int>(0, (sum, s) => sum + (s['durationMinutes'] as int? ?? 0));
              final pieceBreakdown = _pieceBreakdown(recentSessions);
              final instrumentBreakdown = _instrumentBreakdown(recentSessions);
              final sortedPieces = pieceBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final sortedInstruments = instrumentBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

              return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]),
                child: Row(children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    if (instrument.isNotEmpty) Text(instrument, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [_StatBox(emoji: '🔥', value: '$streak', label: 'Current Streak'), const SizedBox(width: 12), _StatBox(emoji: '🏆', value: '$longestStreak', label: 'Best Streak')]),
              const SizedBox(height: 12),
              Row(children: [_StatBox(emoji: '📅', value: '$totalSessions', label: 'Total Sessions'), const SizedBox(width: 12), _StatBox(emoji: '⏱', value: timeStr, label: 'Total Practice')]),
              const SizedBox(height: 24),

              Row(children: [
                const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF00BFA5), size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(sinceDate != null ? 'Since Last Assignment (${_formatFullDate(sinceDate)})' : 'Practice Activity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
              ]),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.timer_outlined, color: Color(0xFF00BFA5), size: 18),
                    const SizedBox(width: 8),
                    Text('$recentMinutes min across ${recentSessions.length} session${recentSessions.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                  if (recentSessions.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('No sessions logged since the last assignment was sent.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                  if (sortedInstruments.length > 1) ...[
                    const SizedBox(height: 14),
                    const Text('By Instrument', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...sortedInstruments.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.piano, size: 13, color: Color(0xFF2196F3)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                        Text('${e.value} min', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    )),
                  ],
                  if (sortedPieces.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('By Piece', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...sortedPieces.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.music_note, size: 13, color: Color(0xFFE91E8C)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                        Text('${e.value} min', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    )),
                  ],
                ]),
              ),
              const SizedBox(height: 24),

              if (repertoire.isNotEmpty) ...[
                const Text('Repertoire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                ...repertoire.map((piece) {
                  final title = piece['title'] as String? ?? '';
                  final composer = piece['composer'] as String? ?? '';
                  final status = piece['status'] as String? ?? '';
                  if (title.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(14), border: Border.all(color: _purple.withOpacity(0.2))),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE91E8C).withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.music_note, color: Color(0xFFE91E8C), size: 16)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        if (composer.isNotEmpty) Text(composer, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ])),
                      if (status.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(status, style: const TextStyle(color: Color(0xFF9B59B6), fontSize: 10))),
                    ]),
                  );
                }),
              ],
            ]),
              );
            },
          ),

          // ── TAB 2: SESSIONS ──
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService().getStudentSessions(widget.studentUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _purple));
              final sessions = snapshot.data ?? [];
              if (sessions.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.timer_outlined, color: Colors.white30, size: 48),
                  const SizedBox(height: 12),
                  const Text('No sessions yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('${name.split(' ').first} hasn\'t logged any sessions yet.', style: const TextStyle(color: Colors.white38, fontSize: 13)),
                ]));
              }

              final recentSessions = _sessionsSince(sessions, sinceDate);
              final recentMinutes = recentSessions.fold<int>(0, (sum, s) => sum + (s['durationMinutes'] as int? ?? 0));
              final recentIds = recentSessions.map((s) => s['id']).toSet();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                itemCount: sessions.length + (sinceDate != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (sinceDate != null && index == 0) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.35))),
                      child: Row(children: [
                        const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF00BFA5), size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Since last assignment (${_formatFullDate(sinceDate)}): $recentMinutes min across ${recentSessions.length} session${recentSessions.length == 1 ? '' : 's'}', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 12, fontWeight: FontWeight.w600))),
                      ]),
                    );
                  }
                  final s = sessions[sinceDate != null ? index - 1 : index];
                  final date = _formatDate(s['date'] as String? ?? '');
                  final duration = s['durationMinutes'] as int? ?? 0;
                  final piece = s['piece'] as String? ?? '';
                  final notes = s['notes'] as String? ?? '';
                  final inst = s['instrument'] as String? ?? '';
                  final isRecent = recentIds.contains(s['id']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(16), border: Border.all(color: isRecent ? const Color(0xFF00BFA5).withOpacity(0.4) : _purple.withOpacity(0.2))),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isRecent ? const Color(0xFF00BFA5) : _purple).withOpacity(0.15), shape: BoxShape.circle), child: Icon(Icons.timer_outlined, color: isRecent ? const Color(0xFF00BFA5) : _purple, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('$duration min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          if (inst.isNotEmpty) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(inst, style: const TextStyle(color: Color(0xFF9B59B6), fontSize: 10)))],
                        ]),
                        if (piece.isNotEmpty) Text(piece, style: const TextStyle(color: Color(0xFFE91E8C), fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(notes.isEmpty ? date : '$date • $notes', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                  );
                },
              );
            },
          ),

          // ── TAB 3: ASSIGNMENTS ──
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService().getStudentAssignments(widget.studentUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _purple));
              final assignments = snapshot.data ?? [];
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentScreen(studentUid: widget.studentUid, studentName: name))),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Assignment'),
                    style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  )),
                ),
                if (assignments.isEmpty)
                  Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.assignment_outlined, color: Colors.white30, size: 48),
                    const SizedBox(height: 12),
                    const Text('No assignments yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Tap the button above to assign\nhomework to ${name.split(' ').first}.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                  ])))
                else
                  Expanded(child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
                    itemCount: assignments.length,
                    itemBuilder: (context, index) {
                      final a = assignments[index];
                      final title = a['title'] as String? ?? '';
                      final piece = a['piece'] as String? ?? '';
                      final notes = a['notes'] as String? ?? '';
                      final completed = a['completed'] as bool? ?? false;
                      final checklist = (a['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                      final completedItems = checklist.where((i) => i['checked'] == true).length;
                      final assignmentId = a['id'] as String? ?? '';
                      final feedback = a['teacherFeedback'] as String? ?? '';

                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssignmentScreen(studentUid: widget.studentUid, studentName: name, existingAssignment: a))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: completed ? [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.08)] : [_cardBg, _cardBg2]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: completed ? Colors.green.withOpacity(0.4) : _purple.withOpacity(0.2)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(completed ? Icons.check_circle : Icons.assignment_outlined, color: completed ? Colors.green : _purple, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(title, style: TextStyle(color: completed ? Colors.green : Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                if (completed) const Text('Student completed ✓', style: TextStyle(color: Colors.green, fontSize: 11)),
                              ])),
                              const Icon(Icons.edit_outlined, color: Colors.white38, size: 16),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showFeedbackDialog(assignmentId, feedback, a),
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _purple.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.comment_outlined, color: Color(0xFF9B59B6), size: 16)),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: _cardBg, title: const Text('Delete Assignment', style: TextStyle(color: Colors.white)), content: const Text('Remove this assignment?', style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Delete'))]));
                                  if (confirm == true) await FirestoreService().deleteAssignment(widget.studentUid, assignmentId);
                                },
                                child: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                              ),
                            ]),
                            if (piece.isNotEmpty) ...[const SizedBox(height: 4), Text(piece, style: const TextStyle(color: Color(0xFFE91E8C), fontSize: 12, fontWeight: FontWeight.w600))],
                            if (notes.isNotEmpty) ...[const SizedBox(height: 4), Text(notes, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4))],
                            if (feedback.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _purple.withOpacity(0.2))), child: Row(children: [const Icon(Icons.comment_outlined, color: Color(0xFF9B59B6), size: 12), const SizedBox(width: 6), Expanded(child: Text(feedback, style: const TextStyle(color: Color(0xFF9B59B6), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis))])),
                            ],
                            if (checklist.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: checklist.isEmpty ? 0 : completedItems / checklist.length, backgroundColor: Colors.white12, color: Colors.green, borderRadius: BorderRadius.circular(4)),
                              const SizedBox(height: 4),
                              Text('$completedItems / ${checklist.length} items completed', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ]),
                        ),
                      );
                    },
                  )),
              ]);
            },
          ),

            ]);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STAT BOX
// ─────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _StatBox({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF6B21FF).withOpacity(0.2))),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }
}