import 'package:flutter/material.dart';
import '../firestore_service.dart';
import '../auth_service.dart';

class AssignmentsWidget extends StatelessWidget {
  const AssignmentsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AuthService().isLoggedIn) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().getMyAssignments(),
      builder: (context, snapshot) {
        final assignments = snapshot.data ?? [];
        if (assignments.isEmpty) return const SizedBox.shrink();

        final activeCount = assignments.where((a) => !(a['completed'] as bool? ?? false)).length;
        final unseenCount = assignments.where((a) => !(a['seenByStudent'] as bool? ?? true)).length;
        final unseenFeedback = assignments.where((a) =>
          a['teacherFeedback'] != null &&
          !(a['feedbackSeenByStudent'] as bool? ?? true)
        ).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.assignment_outlined, size: 16, color: Color(0xFFFF6B35))),
            const SizedBox(width: 10),
            const Text('Teacher Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (unseenCount > 0 || unseenFeedback > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFF6B35), borderRadius: BorderRadius.circular(10)),
                child: Text('${unseenCount + unseenFeedback} new', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text('$activeCount active', style: const TextStyle(fontSize: 11, color: Color(0xFFFF6B35), fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          ...assignments.map((a) => _AssignmentCard(assignment: a)),
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}

class _AssignmentCard extends StatefulWidget {
  final Map<String, dynamic> assignment;
  const _AssignmentCard({required this.assignment});

  @override
  State<_AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<_AssignmentCard> {
  bool _expanded = false;
  late Map<String, dynamic> _assignment;

  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _orange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _assignment = Map<String, dynamic>.from(widget.assignment);
  }

  @override
  void didUpdateWidget(_AssignmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _assignment = Map<String, dynamic>.from(widget.assignment);
  }

  Future<void> _onExpand() async {
    setState(() => _expanded = !_expanded);
    // Mark as seen when student opens it
    if (_expanded) {
      final assignmentId = _assignment['id'] as String;
      final notSeen = !(_assignment['seenByStudent'] as bool? ?? true);
      final hasFeedback = _assignment['teacherFeedback'] != null;
      final feedbackNotSeen = !((_assignment['feedbackSeenByStudent'] as bool?) ?? true);
      if (notSeen) await FirestoreService().markAssignmentSeen(assignmentId);
      if (hasFeedback && feedbackNotSeen) await FirestoreService().markFeedbackSeen(assignmentId);
    }
  }

  Future<void> _togglePieceItem(int pieceIndex, int itemIndex) async {
    final pieces = List<Map<String, dynamic>>.from(
      (_assignment['pieces'] as List<dynamic>? ?? []).map((p) => Map<String, dynamic>.from(p as Map))
    );
    if (pieceIndex >= pieces.length) return;
    final pieceChecklist = List<Map<String, dynamic>>.from(
      (pieces[pieceIndex]['checklistItems'] as List<dynamic>? ?? []).map((i) => Map<String, dynamic>.from(i as Map))
    );
    if (itemIndex >= pieceChecklist.length) return;
    pieceChecklist[itemIndex]['checked'] = !(pieceChecklist[itemIndex]['checked'] as bool? ?? false);
    pieces[pieceIndex]['checklistItems'] = pieceChecklist;
    final allChecked = pieces.every((p) =>
      (p['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>().every((i) => i['checked'] == true)
    );
    setState(() {
      _assignment['pieces'] = pieces;
      if (allChecked) _assignment['completed'] = true;
    });
    final assignmentId = _assignment['id'] as String;
    await FirestoreService().updateAssignment(assignmentId, {
      'pieces': pieces,
      if (allChecked) 'completed': true,
    });
  }

  Future<void> _toggleItem(int index) async {
    final checklist = List<Map<String, dynamic>>.from(
      (_assignment['checklistItems'] as List<dynamic>).map((i) => Map<String, dynamic>.from(i as Map))
    );
    checklist[index]['checked'] = !(checklist[index]['checked'] as bool? ?? false);
    final allChecked = checklist.every((i) => i['checked'] == true);
    setState(() {
      _assignment['checklistItems'] = checklist;
      if (allChecked) _assignment['completed'] = true;
    });
    final assignmentId = _assignment['id'] as String;
    await FirestoreService().updateAssignment(assignmentId, {
      'checklistItems': checklist,
      if (allChecked) 'completed': true,
    });
  }

  Future<void> _markComplete() async {
    setState(() => _assignment['completed'] = true);
    await FirestoreService().updateAssignment(_assignment['id'] as String, {'completed': true});
  }

  Future<void> _markIncomplete() async {
    setState(() => _assignment['completed'] = false);
    await FirestoreService().updateAssignment(_assignment['id'] as String, {'completed': false});
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Delete Assignment', style: TextStyle(color: Colors.white)),
        content: const Text('Remove this assignment from your home screen?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      final uid = AuthService().currentUser?.uid;
      if (uid != null) await FirestoreService().deleteAssignment(uid, _assignment['id'] as String);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _assignment['title'] as String? ?? '';
    final notes = _assignment['notes'] as String? ?? '';
    final completed = _assignment['completed'] as bool? ?? false;
    final pieces = (_assignment['pieces'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final checklist = (_assignment['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final piece = _assignment['piece'] as String? ?? '';
    final completedItems = checklist.where((i) => i['checked'] == true).length;
    final isNew = !(_assignment['seenByStudent'] as bool? ?? true);
    final feedback = _assignment['teacherFeedback'] as String?;
    final feedbackNew = feedback != null && !(_assignment['feedbackSeenByStudent'] as bool? ?? true);

    return GestureDetector(
      onTap: _onExpand,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: completed ? [Colors.green.withOpacity(0.12), Colors.green.withOpacity(0.06)] : [_cardBg, _cardBg2]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isNew ? _orange : completed ? Colors.green.withOpacity(0.4) : _orange.withOpacity(0.4), width: isNew ? 2 : 1),
          boxShadow: [BoxShadow(color: isNew ? _orange.withOpacity(0.2) : Colors.transparent, blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: completed ? Colors.green.withOpacity(0.15) : _orange.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(completed ? Icons.check_circle : Icons.assignment_outlined, color: completed ? Colors.green : _orange, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: TextStyle(color: completed ? Colors.green : Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
                  if (isNew) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(8)), child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                  if (feedbackNew && !isNew) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(8)), child: const Text('FEEDBACK', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                ]),
                if (pieces.isNotEmpty)
                  Text(pieces.map((p) => p['piece'] as String? ?? '').where((s) => s.isNotEmpty).join(' • '), style: const TextStyle(color: Color(0xFFE91E8C), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
                else if (piece.isNotEmpty)
                  Text(piece, style: const TextStyle(color: Color(0xFFE91E8C), fontSize: 12, fontWeight: FontWeight.w600)),
                if (completed) const Text('Completed ✓', style: TextStyle(color: Colors.green, fontSize: 11)),
              ])),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white38, size: 20),
              const SizedBox(width: 4),
              GestureDetector(onTap: _delete, child: const Icon(Icons.delete_outline, color: Colors.white24, size: 18)),
            ]),
          ),

          // Progress bar (collapsed)
          if (checklist.isNotEmpty && !_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LinearProgressIndicator(value: checklist.isEmpty ? 0 : completedItems / checklist.length, backgroundColor: Colors.white12, color: completed ? Colors.green : _orange, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 4),
                Text('$completedItems / ${checklist.length} completed', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
            ),

          // Expanded content
          if (_expanded) ...[
            const Divider(color: Colors.white12, height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Total suggested time
                if (pieces.any((p) => p['suggestedMinutes'] != null)) ...[
                  Builder(builder: (context) {
                    final total = pieces.fold<int>(0, (sum, p) => sum + ((p['suggestedMinutes'] as int?) ?? 0));
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.25))),
                      child: Row(children: [
                        const Icon(Icons.timer_outlined, color: Color(0xFF00BFA5), size: 16),
                        const SizedBox(width: 8),
                        Text('Suggested practice time: $total min', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    );
                  }),
                ],

                // General notes
                if (notes.isNotEmpty) ...[
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _orange.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _orange.withOpacity(0.2))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.notes, color: _orange, size: 14), const SizedBox(width: 8), Expanded(child: Text(notes, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)))])),
                  const SizedBox(height: 14),
                ],

                // Teacher feedback
                if (feedback != null && feedback.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _purple.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: feedbackNew ? _purple : _purple.withOpacity(0.3), width: feedbackNew ? 1.5 : 1)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.comment_outlined, color: Color(0xFF9B59B6), size: 14),
                        const SizedBox(width: 6),
                        const Text('Teacher Feedback', style: TextStyle(color: Color(0xFF9B59B6), fontSize: 12, fontWeight: FontWeight.w600)),
                        if (feedbackNew) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(6)), child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))],
                      ]),
                      const SizedBox(height: 8),
                      Text(feedback, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // Pieces with checklists
                if (pieces.isNotEmpty) ...[
                  ...pieces.asMap().entries.map((pieceEntry) {
                    final p = pieceEntry.value;
                    final pieceName = p['piece'] as String? ?? '';
                    final pieceChecklist = (p['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (pieceName.isNotEmpty) ...[
                        Row(children: [
                          const Icon(Icons.music_note, color: Color(0xFFE91E8C), size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(pieceName, style: const TextStyle(color: Color(0xFFE91E8C), fontSize: 13, fontWeight: FontWeight.w700))),
                          if (p['suggestedMinutes'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.timer_outlined, size: 11, color: Color(0xFF00BFA5)),
                                const SizedBox(width: 3),
                                Text('${p['suggestedMinutes']} min', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 11, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                        ]),
                        const SizedBox(height: 8),
                      ],
                      ...pieceChecklist.asMap().entries.map((itemEntry) {
                        final item = itemEntry.value;
                        final checked = item['checked'] as bool? ?? false;
                        return GestureDetector(
                          onTap: () => _togglePieceItem(pieceEntry.key, itemEntry.key),
                          child: Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Row(children: [
                            Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked, color: checked ? Colors.green : _orange.withOpacity(0.6), size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item['text'] as String? ?? '', style: TextStyle(color: checked ? Colors.white38 : Colors.white, fontSize: 13, decoration: checked ? TextDecoration.lineThrough : null))),
                          ])),
                        );
                      }),
                      const SizedBox(height: 10),
                    ]);
                  }),
                ] else if (checklist.isNotEmpty) ...[
                  ...checklist.asMap().entries.map((entry) {
                    final item = entry.value;
                    final checked = item['checked'] as bool? ?? false;
                    return GestureDetector(
                      onTap: () => _toggleItem(entry.key),
                      child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                        Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked, color: checked ? Colors.green : _orange.withOpacity(0.6), size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item['text'] as String? ?? '', style: TextStyle(color: checked ? Colors.white38 : Colors.white, fontSize: 13, decoration: checked ? TextDecoration.lineThrough : null))),
                      ])),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Complete / Incomplete buttons
                if (!completed)
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _markComplete, style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.2), foregroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.withOpacity(0.3)))), child: const Text('Mark as Complete', style: TextStyle(fontWeight: FontWeight.w600))))
                else
                  SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _markIncomplete, style: OutlinedButton.styleFrom(foregroundColor: Colors.white38, side: BorderSide(color: Colors.white12), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Mark as Incomplete', style: TextStyle(fontSize: 12)))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}