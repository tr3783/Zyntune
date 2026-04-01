import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class Song {
  final String id;
  String title;
  String composer;
  String movements;
  String status;
  String notes;
  String link;

  Song({
    required this.id,
    required this.title,
    required this.composer,
    required this.movements,
    required this.status,
    this.notes = '',
    this.link = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'composer': composer,
        'movements': movements,
        'status': status,
        'notes': notes,
        'link': link,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'],
        title: json['title'],
        composer: json['composer'] ?? '',
        movements: json['movements'] ?? '',
        status: json['status'],
        notes: json['notes'] ?? '',
        link: json['link'] ?? '',
      );
}

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  List<Song> _songs = [];
  String _filterStatus = 'All';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _movementsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  String _selectedStatus = 'learning';

  final Map<String, Color> _statusColors = {
    'learning': Colors.red,
    'in progress': Colors.orange,
    'mastered': Colors.green,
  };

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _movementsController.dispose();
    _notesController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('songs') ?? [];
    setState(() {
      _songs = data.map((s) => Song.fromJson(jsonDecode(s))).toList();
    });
  }

  Future<void> _saveSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _songs.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('songs', data);
  }

  void _addSong() {
    if (_titleController.text.trim().isEmpty) return;
    final newSong = Song(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      composer: _composerController.text.trim(),
      movements: _movementsController.text.trim(),
      status: _selectedStatus,
      notes: _notesController.text.trim(),
      link: _linkController.text.trim(),
    );
    setState(() => _songs.add(newSong));
    _saveSongs();
    _clearControllers();
    Navigator.pop(context);
  }

  void _clearControllers() {
    _titleController.clear();
    _composerController.clear();
    _movementsController.clear();
    _notesController.clear();
    _linkController.clear();
    _selectedStatus = 'learning';
  }

  void _deleteSong(String id) {
    setState(() => _songs.removeWhere((s) => s.id == id));
    _saveSongs();
  }

  void _updateStatus(String id, String newStatus) {
    setState(() {
      final song = _songs.firstWhere((s) => s.id == id);
      song.status = newStatus;
    });
    _saveSongs();
  }

  List<Song> get _filteredSongs {
    if (_filterStatus == 'All') return _songs;
    return _songs.where((s) => s.status == _filterStatus).toList();
  }

  // Launch URL in browser
  Future<void> _launchLink(String url) async {
    // Add https:// if missing
    final fullUrl =
        url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.parse(fullUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddSongDialog() {
    _clearControllers();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add to Repertoire'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g. Moonlight Sonata',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.music_note),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _composerController,
                  decoration: const InputDecoration(
                    labelText: 'Composer',
                    hintText: 'e.g. Ludwig van Beethoven',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _movementsController,
                  decoration: const InputDecoration(
                    labelText: 'Movements / Sections',
                    hintText: 'e.g. I. Adagio, II. Allegretto',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.format_list_numbered),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: ['learning', 'in progress', 'mastered']
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => _selectedStatus = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Practice Notes',
                    hintText: 'e.g. Work on the coda section',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Link (optional)',
                    hintText: 'e.g. youtube.com/watch?v=...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
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
              onPressed: _addSong,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(song.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (song.composer.isNotEmpty)
                _DetailRow(
                  icon: Icons.person,
                  label: 'Composer',
                  value: song.composer,
                ),
              if (song.movements.isNotEmpty)
                _DetailRow(
                  icon: Icons.format_list_numbered,
                  label: 'Movements',
                  value: song.movements,
                ),
              _DetailRow(
                icon: Icons.flag,
                label: 'Status',
                value: song.status.toUpperCase(),
              ),
              if (song.notes.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes,
                  label: 'Notes',
                  value: song.notes,
                ),

              // Tappable link row
              if (song.link.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.link,
                        size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('Reference Link',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey)),
                          GestureDetector(
                            onTap: () =>
                                _launchLink(song.link),
                            child: Text(
                              song.link,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                                decoration:
                                    TextDecoration.underline,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Open link button
                    IconButton(
                      icon: const Icon(Icons.open_in_new,
                          color: Colors.blue),
                      onPressed: () => _launchLink(song.link),
                      tooltip: 'Open link',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
        title: const Text('🎼 My Repertoire',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSongDialog,
        backgroundColor: Colors.pink,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [

            // --- Stats Row ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  label: 'Learning',
                  count: _songs
                      .where((s) => s.status == 'learning')
                      .length,
                  color: Colors.red,
                ),
                _StatChip(
                  label: 'In Progress',
                  count: _songs
                      .where((s) => s.status == 'in progress')
                      .length,
                  color: Colors.orange,
                ),
                _StatChip(
                  label: 'Mastered',
                  count: _songs
                      .where((s) => s.status == 'mastered')
                      .length,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Filter Chips ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'learning',
                  'in progress',
                  'mastered'
                ]
                    .map((status) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(status.toUpperCase()),
                            selected: _filterStatus == status,
                            onSelected: (_) => setState(
                                () => _filterStatus = status),
                            selectedColor:
                                Colors.pink.withOpacity(0.3),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // --- Songs List ---
            Expanded(
              child: _filteredSongs.isEmpty
                  ? Center(
                      child: Text(
                        _songs.isEmpty
                            ? 'No pieces yet!\nTap + to add to your repertoire 🎼'
                            : 'No pieces with this status.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface
                              .withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = _filteredSongs[index];
                        final statusColor =
                            _statusColors[song.status] ??
                                Colors.grey;
                        return Card(
                          margin:
                              const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () =>
                                _showDetailDialog(song),
                            leading: CircleAvatar(
                              backgroundColor:
                                  statusColor.withOpacity(0.2),
                              child: Icon(Icons.music_note,
                                  color: statusColor),
                            ),
                            title: Text(
                              song.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              song.composer.isEmpty
                                  ? song.status.toUpperCase()
                                  : '${song.composer} • ${song.status.toUpperCase()}',
                            ),
                            // Show link icon if link exists
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (song.link.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                        Icons.open_in_new,
                                        color: Colors.blue,
                                        size: 20),
                                    onPressed: () =>
                                        _launchLink(song.link),
                                    tooltip: 'Open link',
                                  ),
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                      Icons.more_vert),
                                  onSelected: (val) {
                                    if (val == 'delete') {
                                      _deleteSong(song.id);
                                    } else {
                                      _updateStatus(
                                          song.id, val);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'learning',
                                      child: Text(
                                          'Mark: Learning'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'in progress',
                                      child: Text(
                                          'Mark: In Progress'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'mastered',
                                      child: Text(
                                          'Mark: Mastered'),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete',
                                          style: TextStyle(
                                              color:
                                                  Colors.red)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.pink),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                Text(value,
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}