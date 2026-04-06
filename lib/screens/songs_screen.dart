import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

enum PieceStatus { wishlist, workingOn, performanceReady }

enum MovementStatus { notStarted, learning, performanceReady }

class Movement {
  final String id;
  String title;
  MovementStatus status;

  Movement({
    required this.id,
    required this.title,
    this.status = MovementStatus.notStarted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status.name,
      };

  factory Movement.fromJson(Map<String, dynamic> json) =>
      Movement(
        id: json['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] ?? '',
        status: MovementStatus.values.firstWhere(
            (s) => s.name == (json['status'] ?? 'notStarted'),
            orElse: () => MovementStatus.notStarted),
      );
}

class Piece {
  final String id;
  String title;
  String composer;
  List<Movement> movements;
  PieceStatus status;
  String notes;
  String link;

  Piece({
    required this.id,
    required this.title,
    required this.composer,
    required this.status,
    List<Movement>? movements,
    this.notes = '',
    this.link = '',
  }) : movements = movements ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'composer': composer,
        'movements': movements.map((m) => m.toJson()).toList(),
        'status': status.name,
        'notes': notes,
        'link': link,
      };

  factory Piece.fromJson(Map<String, dynamic> json) {
    PieceStatus status;
    final rawStatus = json['status'] ?? 'workingOn';
    if (rawStatus == 'learning' || rawStatus == 'in progress') {
      status = PieceStatus.workingOn;
    } else if (rawStatus == 'mastered' ||
        rawStatus == 'performanceReady') {
      status = PieceStatus.performanceReady;
    } else if (rawStatus == 'wishlist') {
      status = PieceStatus.wishlist;
    } else {
      status = PieceStatus.workingOn;
    }

    List<Movement> movements = [];
    final rawMovements = json['movements'];
    if (rawMovements is List) {
      movements = rawMovements
          .map((m) => m is Map<String, dynamic>
              ? Movement.fromJson(m)
              : Movement(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  title: m.toString()))
          .toList();
    } else if (rawMovements is String && rawMovements.isNotEmpty) {
      movements = [
        Movement(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: rawMovements,
        )
      ];
    }

    return Piece(
      id: json['id'],
      title: json['title'],
      composer: json['composer'] ?? '',
      movements: movements,
      status: status,
      notes: json['notes'] ?? '',
      link: json['link'] ?? '',
    );
  }
}

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  List<Piece> _pieces = [];
  PieceStatus? _filterStatus;

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  void initState() {
    super.initState();
    _loadPieces();
  }

  Future<void> _loadPieces() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('songs') ?? [];
    setState(() {
      _pieces =
          data.map((s) => Piece.fromJson(jsonDecode(s))).toList();
    });
  }

  Future<void> _savePieces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'songs', _pieces.map((s) => jsonEncode(s.toJson())).toList());
  }

  Color _statusColor(PieceStatus status) {
    switch (status) {
      case PieceStatus.wishlist:
        return const Color(0xFF2196F3);
      case PieceStatus.workingOn:
        return const Color(0xFFFF6B35);
      case PieceStatus.performanceReady:
        return const Color(0xFF4CAF50);
    }
  }

  IconData _statusIcon(PieceStatus status) {
    switch (status) {
      case PieceStatus.wishlist:
        return Icons.bookmark_outline;
      case PieceStatus.workingOn:
        return Icons.music_note;
      case PieceStatus.performanceReady:
        return Icons.star;
    }
  }

  String _statusLabel(PieceStatus status) {
    switch (status) {
      case PieceStatus.wishlist:
        return 'Wish List';
      case PieceStatus.workingOn:
        return 'Working On';
      case PieceStatus.performanceReady:
        return 'Perf. Ready';
    }
  }

  Color _movementStatusColor(MovementStatus status) {
    switch (status) {
      case MovementStatus.notStarted:
        return Colors.grey;
      case MovementStatus.learning:
        return Colors.orange;
      case MovementStatus.performanceReady:
        return Colors.green;
    }
  }

  String _movementStatusLabel(MovementStatus status) {
    switch (status) {
      case MovementStatus.notStarted:
        return 'Not Started';
      case MovementStatus.learning:
        return 'Learning';
      case MovementStatus.performanceReady:
        return 'Performance Ready';
    }
  }

  List<Piece> get _filteredPieces {
    if (_filterStatus == null) return _pieces;
    return _pieces.where((p) => p.status == _filterStatus).toList();
  }

  Future<void> _launchLink(String url) async {
    final fullUrl = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.parse(fullUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  void _addMovementToList(
      String text,
      List<Movement> movements,
      TextEditingController controller,
      StateSetter setDialogState) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setDialogState(() {
      movements.add(Movement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: trimmed,
      ));
      controller.clear();
    });
  }

  Widget _buildMovementsList(
      List<Movement> movements,
      TextEditingController movementController,
      StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Movements / Sections',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 8),
        ...movements.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _movementStatusColor(m.status)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _movementStatusColor(m.status)
                                .withOpacity(0.3)),
                      ),
                      child: Text(m.title,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<MovementStatus>(
                    icon: Icon(Icons.more_vert,
                        size: 18,
                        color: _movementStatusColor(m.status)),
                    onSelected: (val) =>
                        setDialogState(() => m.status = val),
                    itemBuilder: (_) => MovementStatus.values
                        .map((s) => PopupMenuItem(
                              value: s,
                              child: Text(_movementStatusLabel(s)),
                            ))
                        .toList(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: Colors.red),
                    onPressed: () =>
                        setDialogState(() => movements.remove(m)),
                  ),
                ],
              ),
            )),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: movementController,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add movement/section...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _purple.withOpacity(0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _purple.withOpacity(0.4)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                ),
                onSubmitted: (val) => _addMovementToList(
                    val, movements, movementController, setDialogState),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle,
                  color: Color(0xFFE91E8C)),
              onPressed: () => _addMovementToList(movementController.text,
                  movements, movementController, setDialogState),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddPieceDialog() {
    final titleController = TextEditingController();
    final composerController = TextEditingController();
    final notesController = TextEditingController();
    final linkController = TextEditingController();
    final movementController = TextEditingController();
    PieceStatus selectedStatus = PieceStatus.workingOn;
    List<Movement> movements = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Add Piece',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _darkTextField(titleController, 'Title *',
                    'e.g. Moonlight Sonata', Icons.music_note),
                const SizedBox(height: 12),
                _darkTextField(composerController, 'Composer',
                    'e.g. Beethoven', Icons.person),
                const SizedBox(height: 12),
                const Text('Status',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PieceStatus.values.map((status) {
                    final isSelected = selectedStatus == status;
                    final color = _statusColor(status);
                    return GestureDetector(
                      onTap: () => setDialogState(
                          () => selectedStatus = status),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color
                              : color.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withOpacity(0.4)),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? Colors.white
                                : color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildMovementsList(
                    movements, movementController, setDialogState),
                const SizedBox(height: 12),
                _darkTextField(notesController, 'Notes (optional)',
                    'e.g. Work on the coda', Icons.notes,
                    maxLines: 2),
                const SizedBox(height: 12),
                _darkTextField(linkController,
                    'Reference Link (optional)', 'e.g. youtube.com/...',
                    Icons.link),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                final piece = Piece(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  title: titleController.text.trim(),
                  composer: composerController.text.trim(),
                  status: selectedStatus,
                  movements: List.from(movements),
                  notes: notesController.text.trim(),
                  link: linkController.text.trim(),
                );
                setState(() => _pieces.insert(0, piece));
                _savePieces();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E8C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPieceDialog(Piece piece) {
    final titleController =
        TextEditingController(text: piece.title);
    final composerController =
        TextEditingController(text: piece.composer);
    final notesController =
        TextEditingController(text: piece.notes);
    final linkController =
        TextEditingController(text: piece.link);
    final movementController = TextEditingController();
    PieceStatus selectedStatus = piece.status;
    List<Movement> movements = piece.movements
        .map((m) =>
            Movement(id: m.id, title: m.title, status: m.status))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Edit Piece',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _darkTextField(
                    titleController, 'Title *', '', Icons.music_note),
                const SizedBox(height: 12),
                _darkTextField(
                    composerController, 'Composer', '', Icons.person),
                const SizedBox(height: 12),
                const Text('Status',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PieceStatus.values.map((status) {
                    final isSelected = selectedStatus == status;
                    final color = _statusColor(status);
                    return GestureDetector(
                      onTap: () => setDialogState(
                          () => selectedStatus = status),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color
                              : color.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withOpacity(0.4)),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isSelected ? Colors.white : color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildMovementsList(
                    movements, movementController, setDialogState),
                const SizedBox(height: 12),
                _darkTextField(notesController, 'Notes (optional)',
                    '', Icons.notes,
                    maxLines: 2),
                const SizedBox(height: 12),
                _darkTextField(linkController,
                    'Reference Link (optional)', '', Icons.link),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                setState(() {
                  piece.title = titleController.text.trim();
                  piece.composer = composerController.text.trim();
                  piece.status = selectedStatus;
                  piece.movements = List.from(movements);
                  piece.notes = notesController.text.trim();
                  piece.link = linkController.text.trim();
                });
                _savePieces();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E8C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _purple.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _purple.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _purple),
        ),
      ),
    );
  }

  void _deletePiece(Piece piece) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Delete Piece',
            style: TextStyle(color: Colors.white)),
        content: Text('Delete "${piece.title}"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _pieces.remove(piece));
      _savePieces();
    }
  }

  void _updateStatus(Piece piece, PieceStatus status) {
    setState(() => piece.status = status);
    _savePieces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('My Repertoire',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_purple, Color(0xFF9B59B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPieceDialog,
        backgroundColor: const Color(0xFFE91E8C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            // --- Stats Row ---
            Row(
              children: PieceStatus.values.map((status) {
                final count =
                    _pieces.where((p) => p.status == status).length;
                final color = _statusColor(status);
                final isSelected = _filterStatus == status;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _filterStatus =
                        _filterStatus == status ? null : status),
                    child: Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: [
                                color,
                                color.withOpacity(0.7)
                              ])
                            : LinearGradient(colors: [
                                _cardBg,
                                _cardBg2,
                              ]),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: color.withOpacity(
                                isSelected ? 0.8 : 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(
                                isSelected ? 0.3 : 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? Colors.white
                                  : color,
                            ),
                          ),
                          Text(
                            _statusLabel(status),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // --- Pieces List ---
            Expanded(
              child: _filteredPieces.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_cardBg, _cardBg2],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color:
                                const Color(0xFFE91E8C).withOpacity(0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E8C)
                                  .withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.library_music_outlined,
                              color: Color(0xFFE91E8C),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No pieces yet!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Tap + to add pieces to your repertoire',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredPieces.length,
                      itemBuilder: (context, index) {
                        final piece = _filteredPieces[index];
                        final color = _statusColor(piece.status);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_cardBg, _cardBg2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: color.withOpacity(0.35)),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_statusIcon(piece.status),
                                      color: color, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        piece.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (piece.composer.isNotEmpty)
                                        Text(
                                          piece.composer,
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12),
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                              color:
                                                  color.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
                                            ),
                                            child: Text(
                                              _statusLabel(piece.status),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: color,
                                                  fontWeight:
                                                      FontWeight.w600),
                                            ),
                                          ),
                                          if (piece.movements
                                              .isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '${piece.movements.length} mvmt${piece.movements.length > 1 ? 's' : ''}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white38,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    if (piece.link.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.open_in_new,
                                            color: Color(0xFF2196F3),
                                            size: 18),
                                        onPressed: () =>
                                            _launchLink(piece.link),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18,
                                          color: Color(0xFFE91E8C)),
                                      onPressed: () =>
                                          _showEditPieceDialog(piece),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.white54,
                                          size: 18),
                                      onSelected: (val) {
                                        if (val == 'delete') {
                                          _deletePiece(piece);
                                        } else {
                                          final status =
                                              PieceStatus.values
                                                  .firstWhere((s) =>
                                                      s.name == val);
                                          _updateStatus(piece, status);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        ...PieceStatus.values.map((s) =>
                                            PopupMenuItem(
                                              value: s.name,
                                              child: Row(
                                                children: [
                                                  Icon(_statusIcon(s),
                                                      size: 16,
                                                      color:
                                                          _statusColor(s)),
                                                  const SizedBox(width: 8),
                                                  Text(_statusLabel(s)),
                                                ],
                                              ),
                                            )),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline,
                                                  size: 16,
                                                  color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
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
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE91E8C)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
                Text(value,
                    style: TextStyle(
                        fontSize: 14, color: valueColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}