import 'package:flutter/material.dart';
import '../firestore_service.dart';

class AssignmentPiece {
  String piece;
  int? suggestedMinutes;
  List<String> checklistItems;

  AssignmentPiece({this.piece = '', this.suggestedMinutes, List<String>? checklistItems})
      : checklistItems = checklistItems ?? [];
}

class AssignmentScreen extends StatefulWidget {
  final String studentUid;
  final String studentName;
  final Map<String, dynamic>? existingAssignment;

  const AssignmentScreen({
    super.key,
    required this.studentUid,
    required this.studentName,
    this.existingAssignment,
  });

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late List<AssignmentPiece> _pieces;
  bool _saving = false;
  bool get _isEditing => widget.existingAssignment != null;

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _orange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    final a = widget.existingAssignment;
    _titleController = TextEditingController(text: a?['title'] as String? ?? '');
    _notesController = TextEditingController(text: a?['notes'] as String? ?? '');

    if (a != null) {
      // Load existing pieces from assignment
      final piecesList = (a['pieces'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      if (piecesList.isNotEmpty) {
        _pieces = piecesList.map((p) => AssignmentPiece(
          piece: p['piece'] as String? ?? '',
          suggestedMinutes: p['suggestedMinutes'] as int?,
          checklistItems: (p['checklistItems'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .map((i) => i['text'] as String? ?? '')
              .where((t) => t.isNotEmpty)
              .toList(),
        )).toList();
      } else {
        // Legacy: single piece format
        _pieces = [AssignmentPiece(
          piece: a['piece'] as String? ?? '',
          checklistItems: (a['checklistItems'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .map((i) => i['text'] as String? ?? '')
              .where((t) => t.isNotEmpty)
              .toList(),
        )];
      }
    } else {
      _pieces = [AssignmentPiece()];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addPiece() {
    setState(() => _pieces.add(AssignmentPiece()));
  }

  void _removePiece(int index) {
    if (_pieces.length <= 1) return;
    setState(() => _pieces.removeAt(index));
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title for the assignment.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _saving = true);

    // Build pieces data
    final piecesData = _pieces.map((p) => {
      'piece': p.piece.trim(),
      'suggestedMinutes': p.suggestedMinutes,
      'checklistItems': p.checklistItems.map((text) => {
        'id': DateTime.now().millisecondsSinceEpoch.toString() + text.hashCode.toString(),
        'text': text,
        'checked': false,
      }).toList(),
    }).toList();

    // Keep legacy fields for backwards compat
    final firstPiece = _pieces.isNotEmpty ? _pieces[0].piece.trim() : '';
    final allChecklistItems = _pieces.expand((p) => p.checklistItems).map((text) => {
      'id': DateTime.now().millisecondsSinceEpoch.toString() + text.hashCode.toString(),
      'text': text,
      'checked': false,
    }).toList();

    try {
      if (_isEditing) {
        final assignmentId = widget.existingAssignment!['id'] as String;

        // Preserve checked state for existing items
        final existingPieces = (widget.existingAssignment!['pieces'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        final updatedPieces = _pieces.asMap().entries.map((entry) {
          final index = entry.key;
          final p = entry.value;
          final existingPiece = index < existingPieces.length ? existingPieces[index] : <String, dynamic>{};
          final existingItems = (existingPiece['checklistItems'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          return {
            'piece': p.piece.trim(),
            'suggestedMinutes': p.suggestedMinutes,
            'checklistItems': p.checklistItems.map((text) {
              final existing = existingItems.firstWhere((i) => i['text'] == text, orElse: () => <String, dynamic>{});
              return {
                'id': existing['id'] ?? DateTime.now().millisecondsSinceEpoch.toString() + text.hashCode.toString(),
                'text': text,
                'checked': existing['checked'] ?? false,
              };
            }).toList(),
          };
        }).toList();

        await FirestoreService().updateAssignment(assignmentId, {
          'title': _titleController.text.trim(),
          'notes': _notesController.text.trim(),
          'piece': firstPiece,
          'pieces': updatedPieces,
          'checklistItems': allChecklistItems,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment updated!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        await FirestoreService().createAssignmentV2(
          studentUid: widget.studentUid,
          title: _titleController.text.trim(),
          notes: _notesController.text.trim(),
          pieces: piecesData,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assignment sent to ${widget.studentName}!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save assignment. Try again.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Assignment' : 'Assign to ${widget.studentName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.3))),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _purple.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.assignment_outlined, color: _purple, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_isEditing ? 'Editing Assignment' : 'New Assignment', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('For ${widget.studentName}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ])),
              ]),
            ),
            const SizedBox(height: 24),

            // Title
            _buildLabel('Assignment Title *'),
            const SizedBox(height: 8),
            _buildTextField(_titleController, 'e.g. Week 3 Lesson', maxLines: 1),
            const SizedBox(height: 16),

            // General Notes
            _buildLabel('General Notes (optional)'),
            const SizedBox(height: 8),
            _buildTextField(_notesController, 'e.g. Focus on tone quality and posture', maxLines: 3),
            const SizedBox(height: 24),

            // Pieces
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Pieces to Practice', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: _addPiece,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _orange.withOpacity(0.4))),
                  child: const Row(children: [Icon(Icons.add, color: _orange, size: 16), SizedBox(width: 4), Text('Add Piece', style: TextStyle(color: _orange, fontSize: 12, fontWeight: FontWeight.w600))]),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            ..._pieces.asMap().entries.map((entry) => _PieceCard(
              index: entry.key,
              piece: entry.value,
              canRemove: _pieces.length > 1,
              onRemove: () => _removePiece(entry.key),
              onChanged: () => setState(() {}),
            )),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isEditing ? Icons.save_rounded : Icons.send_rounded, size: 20),
                label: Text(_saving ? 'Saving...' : _isEditing ? 'Save Changes' : 'Send Assignment', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600));

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white30), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.4))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.4))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple, width: 2)), fillColor: const Color(0xFF1A0A4E), filled: true, contentPadding: const EdgeInsets.all(14)),
    );
  }
}

class _PieceCard extends StatefulWidget {
  final int index;
  final AssignmentPiece piece;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _PieceCard({required this.index, required this.piece, required this.canRemove, required this.onRemove, required this.onChanged});

  @override
  State<_PieceCard> createState() => _PieceCardState();
}

class _PieceCardState extends State<_PieceCard> {
  late final TextEditingController _pieceController;
  late final TextEditingController _minutesController;
  final TextEditingController _checklistController = TextEditingController();

  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _orange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _pieceController = TextEditingController(text: widget.piece.piece);
    _pieceController.addListener(() {
      widget.piece.piece = _pieceController.text;
      widget.onChanged();
    });
    _minutesController = TextEditingController(text: widget.piece.suggestedMinutes?.toString() ?? '');
    _minutesController.addListener(() {
      final val = int.tryParse(_minutesController.text);
      widget.piece.suggestedMinutes = (val != null && val > 0) ? val : null;
      widget.onChanged();
    });
  }

  @override
  void dispose() {
    _pieceController.dispose();
    _minutesController.dispose();
    _checklistController.dispose();
    super.dispose();
  }

  void _addItem(String text) {
    if (text.trim().isEmpty) return;
    setState(() { widget.piece.checklistItems.add(text.trim()); _checklistController.clear(); });
    widget.onChanged();
  }

  void _removeItem(int index) {
    setState(() => widget.piece.checklistItems.removeAt(index));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_cardBg, _cardBg2]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _orange.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Piece header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFE91E8C).withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.music_note, color: Color(0xFFE91E8C), size: 14)),
            const SizedBox(width: 8),
            Text('Piece ${widget.index + 1}', style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (widget.canRemove)
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 16)),
              ),
          ]),
        ),

        // Piece name + suggested time
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _pieceController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Piece name (e.g. Bach Prelude in C)',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _orange.withOpacity(0.3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _orange.withOpacity(0.3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _orange, width: 2)),
                  fillColor: Colors.white.withOpacity(0.04),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 78,
              child: TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'min',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  suffixText: 'min',
                  suffixStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF00BFA5).withOpacity(0.3))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF00BFA5).withOpacity(0.3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00BFA5), width: 2)),
                  fillColor: Colors.white.withOpacity(0.04),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('Suggested practice time (optional)', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        ),

        // Checklist items
        if (widget.piece.checklistItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text('Practice Tasks', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 6),
          ...widget.piece.checklistItems.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(children: [
              const Icon(Icons.check_box_outline_blank, size: 16, color: Color(0xFF9B59B6)),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.value, style: const TextStyle(color: Colors.white70, fontSize: 13))),
              GestureDetector(onTap: () => _removeItem(entry.key), child: const Icon(Icons.close, size: 14, color: Colors.white24)),
            ]),
          )),
        ],

        // Add task
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _checklistController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add practice task (e.g. Measures 1-8 slowly)...',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purple.withOpacity(0.2))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purple.withOpacity(0.2))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _purple)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                ),
                onSubmitted: _addItem,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addItem(_checklistController.text),
              child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _purple.withOpacity(0.8), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add, color: Colors.white, size: 18)),
            ),
          ]),
        ),
      ]),
    );
  }
}