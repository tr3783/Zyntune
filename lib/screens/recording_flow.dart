import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation.dart';
import '../recording_service.dart';
import 'paywall_screen.dart';
import 'recordings_screen.dart';

const _purple = Color(0xFF6B21FF);
const _cardBg = Color(0xFF1A0A4E);
const _pink = Color(0xFFE91E8C);
const _recordRed = Color(0xFFE53935);

/// Start recording from anywhere (Recordings screen, timer). Handles the
/// free-tier limit and microphone permission.
Future<void> startRecording(BuildContext context, {String? piece}) async {
  final result = await RecordingService().start(piece: piece);
  if (!context.mounted) return;
  switch (result) {
    case RecordingStartResult.started:
    case RecordingStartResult.alreadyRecording:
      return;
    case RecordingStartResult.needsPro:
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Recording Limit Reached',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Free accounts can keep 3 recordings. Upgrade to Zyntune Pro for unlimited recordings, or delete one to make room.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RecordingsScreen()));
              },
              child: const Text('Manage Recordings',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _purple, foregroundColor: Colors.white),
              child: const Text('Upgrade to Pro'),
            ),
          ],
        ),
      );
    case RecordingStartResult.noPermission:
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Microphone Access Needed',
              style: TextStyle(color: Colors.white)),
          content: const Text(
              'Allow Zyntune to use the microphone in iPhone Settings to record.',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Not Now',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _purple, foregroundColor: Colors.white),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    case RecordingStartResult.failed:
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('Couldn\'t start recording. Please try again.')));
  }
}

/// Stop recording and ask the user to name and save it (or discard it).
Future<void> stopRecording(BuildContext context) async {
  final pending = await RecordingService().stop();
  if (pending == null || !context.mounted) return;
  await showSaveRecordingDialog(context, pending);
}

/// Ask the user to name and save a finished recording (audio or video).
Future<void> showSaveRecordingDialog(BuildContext context, PendingRecording pending) => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SaveRecordingDialog(pending: pending),
    );

class _PieceOption {
  final String title;
  final List<String> movements;
  _PieceOption(this.title, this.movements);
}

Future<List<_PieceOption>> _loadPieces() async {
  final prefs = await SharedPreferences.getInstance();
  final pieces = <_PieceOption>[];
  for (final s in prefs.getStringList('songs') ?? []) {
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      final title = (map['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;
      final raw = map['movements'];
      final movements = raw is List
          ? raw
              .map((m) =>
                  m is Map ? (m['title'] ?? '').toString() : m.toString())
              .where((t) => t.trim().isNotEmpty)
              .toList()
          : (raw is String && raw.trim().isNotEmpty ? [raw] : <String>[]);
      pieces.add(_PieceOption(title, movements));
    } catch (_) {}
  }
  pieces.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return pieces;
}

class _SaveRecordingDialog extends StatefulWidget {
  final PendingRecording pending;
  const _SaveRecordingDialog({required this.pending});

  @override
  State<_SaveRecordingDialog> createState() => _SaveRecordingDialogState();
}

class _SaveRecordingDialogState extends State<_SaveRecordingDialog> {
  late final TextEditingController _title = TextEditingController(
      text: RecordingService.defaultTitle(widget.pending.startedAt, video: widget.pending.isVideo));
  final _notes = TextEditingController();
  bool _titleEdited = false;
  List<_PieceOption> _pieces = [];
  String _piece = '';
  String _movement = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPieces().then((p) {
      if (!mounted) return;
      setState(() => _pieces = p);
      final piece = widget.pending.piece;
      if (piece != null && p.any((o) => o.title == piece)) {
        _selectPiece(piece, '');
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _selectPiece(String piece, String movement) {
    setState(() {
      _piece = piece;
      _movement = movement;
      // Name it after the piece unless the user typed their own name.
      if (!_titleEdited) {
        _title.text = piece.isEmpty
            ? RecordingService.defaultTitle(widget.pending.startedAt, video: widget.pending.isVideo)
            : (movement.isEmpty ? piece : '$piece · $movement');
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final title = _title.text.trim().isEmpty
        ? RecordingService.defaultTitle(widget.pending.startedAt, video: widget.pending.isVideo)
        : _title.text.trim();
    await RecordingService().save(widget.pending,
        title: title,
        piece: _piece,
        movement: _movement,
        notes: _notes.text.trim());
    if (mounted) Navigator.pop(context);
    final messenger =
        ScaffoldMessenger.maybeOf(navigatorKey.currentContext ?? context);
    messenger?.showSnackBar(
        SnackBar(content: Text('Saved "$title" to Recordings.')));
  }

  Future<void> _discard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(widget.pending.isVideo ? 'Discard Video?' : 'Discard Recording?',
            style: const TextStyle(color: Colors.white)),
        content: Text('This ${widget.pending.isVideo ? 'video' : 'recording'} will be deleted.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Keep', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Discard', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await RecordingService().discard(widget.pending);
    if (mounted) Navigator.pop(context);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [_pink, Color(0xFF9B59B6)])
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : _purple.withValues(alpha: 0.3)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final minutes = widget.pending.durationMs ~/ 60000;
    final seconds = (widget.pending.durationMs ~/ 1000) % 60;
    final movements = _pieces
        .where((p) => p.title == _piece)
        .expand((p) => p.movements)
        .toList();
    InputDecoration field(String label) => InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _purple.withValues(alpha: 0.4))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _purple)),
        );

    return AlertDialog(
      backgroundColor: _cardBg,
      title: Text(
          '${widget.pending.isVideo ? '🎥 Save Video' : '🎙 Save Recording'} ($minutes:${seconds.toString().padLeft(2, '0')})',
          style: const TextStyle(color: Colors.white, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _titleEdited = true,
                decoration: field('Name'),
              ),
              if (_pieces.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Piece (optional)',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip('None', _piece.isEmpty, () => _selectPiece('', '')),
                  ..._pieces.map((p) => _chip(p.title, _piece == p.title,
                      () => _selectPiece(p.title, ''))),
                ]),
              ],
              if (movements.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Movement',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip('Whole piece', _movement.isEmpty,
                      () => _selectPiece(_piece, '')),
                  ...movements.map((m) =>
                      _chip(m, _movement == m, () => _selectPiece(_piece, m))),
                ]),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: field('Notes (optional)'),
              ),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : _discard,
            child:
                const Text('Discard', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Shown over every screen while recording: "● Recording 3:12   Stop".
class RecordingBar extends StatelessWidget {
  const RecordingBar({super.key});

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RecordingService(),
      builder: (context, _) {
        final service = RecordingService();
        if (!service.isRecording) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: const Color(0xFF0D0D1A),
          alignment: Alignment.center,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Material(
                color: _recordRed,
                borderRadius: BorderRadius.circular(28),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.fiber_manual_record,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Text('Recording ${_format(service.elapsed)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        final ctx = navigatorKey.currentContext;
                        if (ctx != null) stopRecording(ctx);
                      },
                      style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _recordRed,
                          shape: const StadiumBorder()),
                      child: const Text('Stop',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
