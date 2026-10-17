import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../date_format.dart';
import '../purchase_service.dart';
import '../recording_service.dart';
import '../recordings.dart';
import 'recording_flow.dart';
import 'recording_player_screen.dart';

/// All of the account's recordings, with a big record button. Opened with
/// [piece] it shows that piece's recordings oldest first, to hear progress.
class RecordingsScreen extends StatefulWidget {
  final String? piece;
  const RecordingsScreen({super.key, this.piece});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _pink = Color(0xFFE91E8C);
  static const _recordRed = Color(0xFFE53935);

  List<Recording> _recordings = [];
  bool _loading = true;
  bool _loadFailed = false;
  late String? _pieceFilter = widget.piece;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    RecordingStore.changes.addListener(_load);
    RecordingService().addListener(_onRecordingState);
    _load();
  }

  @override
  void dispose() {
    RecordingStore.changes.removeListener(_load);
    RecordingService().removeListener(_onRecordingState);
    super.dispose();
  }

  void _onRecordingState() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final uid = AuthService().currentUser?.uid;
    List<Recording> list = [];
    var failed = false;
    try {
      if (uid != null) list = await RecordingStore(uid).load();
    } catch (e) {
      debugPrint('Loading recordings failed: $e');
      failed = true;
    }
    if (mounted) {
      setState(() {
        _recordings = list;
        _loading = false;
        _loadFailed = failed;
      });
    }
  }

  List<Recording> get _visible {
    var list = _recordings.where((r) => !_favoritesOnly || r.favorite);
    if (_pieceFilter != null) {
      // One piece: oldest first, so you can hear your progress.
      return list.where((r) => r.piece == _pieceFilter).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return list.toList();
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  Future<void> _toggleFavorite(Recording r) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    r.favorite = !r.favorite;
    await RecordingStore(uid).update(r);
  }

  Widget _recordCard() {
    final service = RecordingService();
    final recording = service.isRecording;
    final isPro = PurchaseService().isPro;
    final left = RecordingStore.freeLimit - _recordings.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (recording ? _recordRed : _purple).withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => recording ? stopRecording(context) : startRecording(context),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _recordRed,
              boxShadow: [BoxShadow(color: _recordRed.withValues(alpha: 0.4), blurRadius: 20)],
            ),
            child: Icon(recording ? Icons.stop_rounded : Icons.mic, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          recording ? 'Recording… tap to stop' : 'Tap to record',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          recording
              ? 'Keeps recording if you lock the screen or use other tools'
              : (isPro ? 'Record a lesson or your practice' : '${left.clamp(0, RecordingStore.freeLimit)} of ${RecordingStore.freeLimit} free recordings left'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(colors: [_pink, Color(0xFF9B59B6)]) : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? Colors.transparent : _purple.withValues(alpha: 0.3)),
            ),
            child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pieces = _recordings.map((r) => r.piece).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final visible = _visible;
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: Text(widget.piece ?? 'Recordings', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        children: [
          _recordCard(),
          const SizedBox(height: 20),
          if (_recordings.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip('All', _pieceFilter == null && !_favoritesOnly, () => setState(() { _pieceFilter = null; _favoritesOnly = false; })),
                _filterChip('⭐ Favorites', _favoritesOnly, () => setState(() => _favoritesOnly = !_favoritesOnly)),
                ...pieces.map((p) => _filterChip(p, _pieceFilter == p, () => setState(() => _pieceFilter = _pieceFilter == p ? null : p))),
              ]),
            ),
          if (_pieceFilter != null && visible.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Oldest to newest — hear your progress', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: _purple)))
          else if (_loadFailed)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Couldn\'t open your recordings. Please close and reopen Zyntune.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _recordings.isEmpty ? 'No recordings yet. Tap the red button to record a lesson or your practice.' : 'No recordings match this filter.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38),
              ),
            )
          else
            ...visible.map((r) => GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordingPlayerScreen(recording: r))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_cardBg, _cardBg2]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _purple.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: _recordRed.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.graphic_eq, color: _recordRed, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (r.piece.isNotEmpty)
                            Text(r.pieceLabel, style: const TextStyle(color: _pink, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${formatFullDate(r.createdAt)} · ${_formatDuration(r.durationMs)}${r.markers.isNotEmpty ? ' · ${r.markers.length} marker${r.markers.length == 1 ? '' : 's'}' : ''}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ]),
                      ),
                      IconButton(
                        tooltip: r.favorite ? 'Remove from favorites' : 'Add to favorites',
                        icon: Icon(r.favorite ? Icons.star_rounded : Icons.star_border_rounded, color: r.favorite ? Colors.amber : Colors.white30),
                        onPressed: () => _toggleFavorite(r),
                      ),
                    ]),
                  ),
                )),
        ],
      ),
    );
  }
}
