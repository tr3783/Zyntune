import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../firestore_service.dart';

class Note {
  final String id;
  String title;
  String content;
  final String date;
  Color color;
  bool fromTeacher;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.color,
    this.fromTeacher = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date,
        'colorValue': color.value,
        'fromTeacher': fromTeacher,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        date: json['date'],
        color: Color(json['colorValue']),
        fromTeacher: json['fromTeacher'] ?? false,
      );
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  final List<Color> _colorOptions = [
    const Color(0xFF6B21FF),
    const Color(0xFF00BFA5),
    const Color(0xFFFF6B35),
    const Color(0xFFE91E8C),
    const Color(0xFF2196F3),
    const Color(0xFF4CAF50),
  ];
  Color _selectedColor = const Color(0xFF6B21FF);

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  static const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  String _formatFullDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr.substring(0, 10));
      return '${_monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return dateStr; }
  }

  List<Note> get _filteredNotes {
    if (_searchQuery.isEmpty) return _notes;
    return _notes.where((n) =>
      n.title.toLowerCase().contains(_searchQuery) ||
      n.content.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('lessonNotes') ?? [];
    var notes = data.map((n) => Note.fromJson(jsonDecode(n))).toList().reversed.toList();

    // Pull any notes added remotely (e.g. by a teacher) that aren't local yet
    try {
      final remoteNotes = await FirestoreService().fetchLessonNotes();
      final localIds = notes.map((n) => n.id).toSet();
      final newOnes = remoteNotes.where((n) => !localIds.contains(n['id'])).map((n) => Note.fromJson(n)).toList();
      if (newOnes.isNotEmpty) {
        notes = [...newOnes, ...notes];
        // Save merged list back (in display order: newest first → stored reversed)
        final toStore = notes.reversed.map((n) => jsonEncode(n.toJson())).toList();
        await prefs.setStringList('lessonNotes', toStore);
      }
    } catch (_) {}

    setState(() {
      _notes = notes;
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _notes.reversed.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList('lessonNotes', data);
    FirestoreService().syncNotes();
  }

  void _addNote() {
    if (_contentController.text.trim().isEmpty) return;
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim().isEmpty ? 'Note ${_notes.length + 1}' : _titleController.text.trim(),
      content: _contentController.text.trim(),
      date: DateTime.now().toString().substring(0, 16),
      color: _selectedColor,
    );
    setState(() => _notes.insert(0, newNote));
    _saveNotes();
    _titleController.clear();
    _contentController.clear();
    _selectedColor = _purple;
    Navigator.pop(context);
  }

  void _deleteNote(String id) {
    setState(() => _notes.removeWhere((n) => n.id == id));
    _saveNotes();
  }

  Widget _highlightedText(String text, String query, {TextStyle? style, int? maxLines}) {
    if (query.isEmpty) return Text(text, style: style, maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : null);
    final lower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int idx;
    while ((idx = lower.indexOf(queryLower, start)) != -1) {
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx), style: style));
      spans.add(TextSpan(text: text.substring(idx, idx + query.length), style: (style ?? const TextStyle()).copyWith(backgroundColor: const Color(0xFF6B21FF).withOpacity(0.4), color: Colors.white, fontWeight: FontWeight.bold)));
      start = idx + query.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start), style: style));
    return RichText(text: TextSpan(children: spans), maxLines: maxLines, overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip);
  }

  void _showAddNoteDialog() {
    _titleController.clear();
    _contentController.clear();
    _selectedColor = _purple;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('New Note', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Title (optional)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  hintText: 'e.g. Lesson notes - April 12',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(Icons.title, color: Colors.white54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _contentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note *',
                  labelStyle: const TextStyle(color: Colors.white60),
                  hintText: 'Write your lesson notes, reminders, ideas...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                ),
                maxLines: 6,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Color', style: TextStyle(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w600))),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _colorOptions.map((color) {
                  final isSelected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () => setDialogState(() => _selectedColor = color),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: isSelected ? 38 : 28, height: isSelected ? 38 : 28, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.white, width: 3) : null, boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10)] : null)),
                  );
                }).toList(),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: _addNote,
              style: ElevatedButton.styleFrom(backgroundColor: _selectedColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save Note'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNoteDialog(Note note) {
    _titleController.text = note.title;
    _contentController.text = note.content;
    Color editColor = note.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Edit Note', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.title, color: Colors.white54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _contentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note',
                  labelStyle: const TextStyle(color: Colors.white60),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                ),
                maxLines: 6,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Color', style: TextStyle(fontSize: 13, color: Colors.white60, fontWeight: FontWeight.w600))),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _colorOptions.map((color) {
                  final isSelected = editColor == color;
                  return GestureDetector(
                    onTap: () => setDialogState(() => editColor = color),
                    child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: isSelected ? 38 : 28, height: isSelected ? 38 : 28, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.white, width: 3) : null, boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10)] : null)),
                  );
                }).toList(),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () {
                if (_contentController.text.trim().isEmpty) return;
                setState(() {
                  note.title = _titleController.text.trim().isEmpty ? note.title : _titleController.text.trim();
                  note.content = _contentController.text.trim();
                  note.color = editColor;
                });
                _saveNotes();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: editColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteDetail(Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: note.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: note.color.withOpacity(0.5), blurRadius: 6)])),
          const SizedBox(width: 10),
          Expanded(child: Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          if (note.fromTeacher) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.school, size: 10, color: Color(0xFFFF6B35)), SizedBox(width: 3), Text('Teacher', style: TextStyle(fontSize: 9, color: Color(0xFFFF6B35), fontWeight: FontWeight.bold))])),
        ]),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_formatFullDate(note.date), style: const TextStyle(fontSize: 12, color: Colors.white38)),
            const SizedBox(height: 14),
            _highlightedText(note.content, _searchQuery, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5)),
          ]),
        ),
        actions: [
          TextButton.icon(onPressed: () { Navigator.pop(context); _deleteNote(note.id); }, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), label: const Text('Delete', style: TextStyle(color: Colors.red))),
          TextButton.icon(onPressed: () { Navigator.pop(context); _showEditNoteDialog(note); }, icon: Icon(Icons.edit_outlined, color: note.color, size: 18), label: Text('Edit', style: TextStyle(color: note.color))),
          ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: note.color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: _isSearching
            ? TextField(controller: _searchController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Search notes...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none))
            : const Text('Lesson Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) { _searchController.clear(); _searchQuery = ''; }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddNoteDialog, backgroundColor: _purple, child: const Icon(Icons.add, color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: _notes.isEmpty
            ? Container(
                width: double.infinity, padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(28), border: Border.all(color: _purple.withOpacity(0.3))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.note_alt_outlined, size: 48, color: Color(0xFF9B59B6))),
                  const SizedBox(height: 20),
                  const Text('No notes yet!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Tap + to add your first lesson note', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)),
                ]),
              )
            : filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.search_off, color: Colors.white30, size: 48),
                    const SizedBox(height: 12),
                    Text('No notes match "$_searchQuery"', style: const TextStyle(color: Colors.white38, fontSize: 14)),
                  ]))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final note = filtered[index];
                      return GestureDetector(
                        onTap: () => _showNoteDetail(note),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [note.color.withOpacity(0.25), note.color.withOpacity(0.12)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: note.color.withOpacity(0.45), width: 1.5),
                            boxShadow: [BoxShadow(color: note.color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: note.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: note.color.withOpacity(0.6), blurRadius: 4)])),
                              const SizedBox(width: 6),
                              Expanded(child: _highlightedText(note.title, _searchQuery, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: note.color), maxLines: 1)),
                              if (note.fromTeacher) Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.school, size: 10, color: Color(0xFFFF6B35))),
                              GestureDetector(onTap: () => _deleteNote(note.id), child: Icon(Icons.close, size: 14, color: note.color.withOpacity(0.6))),
                            ]),
                            const SizedBox(height: 8),
                            Expanded(child: _highlightedText(note.content, _searchQuery, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4), maxLines: 4)),
                            const SizedBox(height: 6),
                            Text(_formatFullDate(note.date), style: const TextStyle(fontSize: 10, color: Colors.white30)),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}