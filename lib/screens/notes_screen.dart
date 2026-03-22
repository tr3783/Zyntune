import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Note {
  final String id;
  String title;
  String content;
  final String date;
  final Color color;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'date': date,
        'colorValue': color.value,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        date: json['date'],
        color: Color(json['colorValue']),
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

  // Note color options
  final List<Color> _colorOptions = [
    Colors.deepPurple,
    Colors.teal,
    Colors.orange,
    Colors.pink,
    Colors.blue,
    Colors.green,
  ];
  Color _selectedColor = Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('lessonNotes') ?? [];
    setState(() {
      _notes = data
          .map((n) => Note.fromJson(jsonDecode(n)))
          .toList()
          .reversed
          .toList();
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final reversed = _notes.reversed.toList();
    final data =
        reversed.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList('lessonNotes', data);
  }

  void _addNote() {
    if (_contentController.text.trim().isEmpty) return;

    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim().isEmpty
          ? 'Note ${_notes.length + 1}'
          : _titleController.text.trim(),
      content: _contentController.text.trim(),
      date: DateTime.now().toString().substring(0, 16),
      color: _selectedColor,
    );

    setState(() => _notes.insert(0, newNote));
    _saveNotes();
    _titleController.clear();
    _contentController.clear();
    _selectedColor = Colors.deepPurple;
    Navigator.pop(context);
  }

  void _deleteNote(String id) {
    setState(() => _notes.removeWhere((n) => n.id == id));
    _saveNotes();
  }

  void _showAddNoteDialog() {
    _titleController.clear();
    _contentController.clear();
    _selectedColor = Colors.deepPurple;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    hintText: 'e.g. Lesson notes - March 20',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),

                // Content
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Note *',
                    hintText:
                        'Write your lesson notes, reminders, ideas...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  autofocus: true,
                ),
                const SizedBox(height: 16),

                // Color picker
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Color:',
                      style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly,
                  children: _colorOptions.map((color) {
                    final isSelected =
                        _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setDialogState(
                          () => _selectedColor = color),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 150),
                        width: isSelected ? 36 : 28,
                        height: isSelected ? 36 : 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white,
                                  width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        color.withOpacity(0.5),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Note'),
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
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: note.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note.date,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                note.content,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _deleteNote(note.id);
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: note.color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 Lesson Notes',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteDialog,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _notes.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.note_add,
                        size: 64,
                        color: colorScheme.onSurface
                            .withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No notes yet!\nTap + to add your first lesson note 📝',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  return GestureDetector(
                    onTap: () => _showNoteDetail(note),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: note.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: note.color.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // Title row
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: note.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  note.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: note.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Content preview
                          Expanded(
                            child: Text(
                              note.content,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface
                                    .withOpacity(0.8),
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Date
                          Text(
                            note.date,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurface
                                  .withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}