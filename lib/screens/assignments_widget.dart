import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth_service.dart';
import '../firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssignmentsWidget extends StatelessWidget {
  const AssignmentsWidget({super.key});

  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _teal = Color(0xFF00BFA5);

  Future<void> _reportTeacher(BuildContext context, String teacherId, String assignmentTitle) async {
    final studentUid = AuthService().currentUser?.uid ?? 'unknown';
    final subject = Uri.encodeComponent('Student Safety Report - Zyntune');
    final body = Uri.encodeComponent(
      'A student has submitted a safety report via Zyntune.\n\n'
      'Student UID: $studentUid\n'
      'Teacher UID: $teacherId\n'
      'Assignment: $assignmentTitle\n'
      'Reported at: ${DateTime.now().toIso8601String()}\n\n'
      'Student message:\n[Student can add details here]',
    );
    final uri = Uri.parse('mailto:zyntuneapp@gmail.com?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showReportDialog(BuildContext context, String teacherId, String assignmentTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.flag_outlined, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text('Report a Concern', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'If you feel unsafe or have received inappropriate communication from your teacher, you can report it to Zyntune.\n\nYour report will open your email app with the details pre-filled.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _reportTeacher(context, teacherId, assignmentTitle);
            },
            icon: const Icon(Icons.send, size: 14),
            label: const Text('Send Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().getMyAssignments(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final assignments = snapshot.data!;
        final active = assignments.where((a) => a['completed'] != true).toList();
        if (active.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.assignment_outlined, color: _teal, size: 18),
              const SizedBox(width: 8),
              const Text('Assignments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _teal.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text('${active.length}', style: const TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),
            ...active.map((assignment) {
              final title = assignment['title'] as String? ?? 'Assignment';
              final notes = assignment['notes'] as String? ?? '';
              final teacherId = assignment['teacherUid'] as String? ?? '';
              final pieces = (assignment['pieces'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
              final checklist = (assignment['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
              final completedItems = checklist.where((i) => i['checked'] == true).length;
              final assignmentId = assignment['id'] as String? ?? '';
              final feedback = assignment['teacherFeedback'] as String? ?? '';
              final seenByStudent = assignment['seenByStudent'] as bool? ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _teal.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: _teal.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _teal.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.assignment_outlined, color: _teal, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                            if (!seenByStudent)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(8)), child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                          ]),
                          const Text('From your teacher', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ])),
                      ]),

                      if (pieces.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...pieces.map((p) {
                          final pieceName = p['piece'] as String? ?? '';
                          final pieceChecklist = (p['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                          final pieceDone = pieceChecklist.where((i) => i['checked'] == true).length;
                          if (pieceName.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                const Icon(Icons.music_note, color: Color(0xFFE91E8C), size: 14),
                                const SizedBox(width: 6),
                                Expanded(child: Text(pieceName, style: const TextStyle(color: Color(0xFFE91E8C), fontSize: 13, fontWeight: FontWeight.w600))),
                                if (pieceChecklist.isNotEmpty)
                                  Text('$pieceDone/${pieceChecklist.length}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ]),
                              if (pieceChecklist.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                ...pieceChecklist.map((item) => _ChecklistItemWidget(
                                  item: item,
                                  assignmentId: assignmentId,
                                  studentUid: uid,
                                  isPieceItem: true,
                                  pieceIndex: pieces.indexOf(p),
                                  itemIndex: pieceChecklist.indexOf(item),
                                )),
                              ],
                            ]),
                          );
                        }),
                      ] else if (checklist.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...checklist.map((item) => _ChecklistItemWidget(
                          item: item,
                          assignmentId: assignmentId,
                          studentUid: uid,
                          isPieceItem: false,
                          pieceIndex: 0,
                          itemIndex: checklist.indexOf(item),
                        )),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: checklist.isEmpty ? 0 : completedItems / checklist.length,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            color: _teal,
                            minHeight: 4,
                          ),
                        ),
                      ],

                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.08))),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.notes, color: Colors.white38, size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(notes, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4))),
                          ]),
                        ),
                      ],

                      if (feedback.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.3))),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.comment_outlined, color: Color(0xFF9B59B6), size: 14),
                            const SizedBox(width: 6),
                            Expanded(child: Text(feedback, style: const TextStyle(color: Color(0xFF9B59B6), fontSize: 12, height: 1.4))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Mark complete button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                                              await FirestoreService().updateAssignment(
                                  assignmentId,
                                  {'completed': true, 'completedAt': DateTime.now().toIso8601String()},
                                );
                              },
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Mark Complete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _teal.withOpacity(0.2),
                                foregroundColor: _teal,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _teal.withOpacity(0.4))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Report button
                          GestureDetector(
                            onTap: () => _showReportDialog(context, teacherId, title),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.withOpacity(0.2)),
                              ),
                              child: const Row(children: [
                                Icon(Icons.flag_outlined, color: Colors.red, size: 14),
                                SizedBox(width: 4),
                                Text('Report', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _ChecklistItemWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final String assignmentId;
  final String studentUid;
  final bool isPieceItem;
  final int pieceIndex;
  final int itemIndex;

  const _ChecklistItemWidget({
    required this.item,
    required this.assignmentId,
    required this.studentUid,
    required this.isPieceItem,
    required this.pieceIndex,
    required this.itemIndex,
  });

  @override
  State<_ChecklistItemWidget> createState() => _ChecklistItemWidgetState();
}

class _ChecklistItemWidgetState extends State<_ChecklistItemWidget> {
  late bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.item['checked'] as bool? ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.item['text'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 20),
      child: GestureDetector(
        onTap: () async {
          setState(() => _checked = !_checked);
                    // Re-fetch the assignment and update the checklist item
          final uid = widget.studentUid;
          final db = FirebaseFirestore.instance;
          final doc = await db.collection('users').doc(uid).collection('assignments').doc(widget.assignmentId).get();
          final data = doc.data();
          if (data == null) return;
          if (widget.isPieceItem) {
            final pieces = (data['pieces'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            if (widget.pieceIndex < pieces.length) {
              final checklist = (pieces[widget.pieceIndex]['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
              if (widget.itemIndex < checklist.length) {
                checklist[widget.itemIndex]['checked'] = _checked;
                pieces[widget.pieceIndex]['checklistItems'] = checklist;
              }
            }
            await db.collection('users').doc(uid).collection('assignments').doc(widget.assignmentId).update({'pieces': pieces});
          } else {
            final checklist = (data['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
            if (widget.itemIndex < checklist.length) {
              checklist[widget.itemIndex]['checked'] = _checked;
            }
            await db.collection('users').doc(uid).collection('assignments').doc(widget.assignmentId).update({'checklistItems': checklist});
          }
        },
        child: Row(children: [
          Icon(
            _checked ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: _checked ? const Color(0xFF00BFA5) : Colors.white38,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: _checked ? Colors.white38 : Colors.white70,
              decoration: _checked ? TextDecoration.lineThrough : null,
            ),
          )),
        ]),
      ),
    );
  }
}