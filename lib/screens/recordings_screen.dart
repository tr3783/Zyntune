import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../date_format.dart';
import '../purchase_service.dart';
import '../recording_service.dart';
import '../recordings.dart';
import 'metronome_control.dart';
import 'recording_flow.dart';
import 'recording_player_screen.dart';
import 'video_record_screen.dart';
import 'paywall_screen.dart';

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
  int _bytes = 0;
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

  // Accounts already checked for unsaved recordings since the app started.
  static final Set<String> _recoveryChecked = {};

  Future<void> _load() async {
    final uid = AuthService().currentUser?.uid;
    List<Recording> list = [];
    var failed = false;
    var recovered = 0;
    try {
      if (uid != null) {
        final store = RecordingStore(uid);
        if (_recoveryChecked.add(uid)) {
          try {
            recovered = await store.recoverUnsaved(inUse: RecordingService().filesInUse);
          } catch (e) {
            debugPrint('Recovering recordings failed: $e');
          }
        }
        list = await store.load();
        _bytes = await store.totalBytes();
      }
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
    if (recovered > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(recovered == 1
            ? 'Found 1 recording that wasn\'t saved — it\'s been added to your list.'
            : 'Found $recovered recordings that weren\'t saved — they\'ve been added to your list.'),
      ));
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

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
    return '${(bytes / 1024).round()} KB';
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

  Future<bool> _confirmDelete(Recording r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(r.isVideo ? 'Delete Video?' : 'Delete Recording?', style: const TextStyle(color: Colors.white)),
        content: Text('"${r.title}" will be permanently deleted from this device.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(Recording r) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    // Remove from the list right away (Dismissible needs it gone), then
    // from the device; the store's change notice reloads the list.
    setState(() => _recordings.removeWhere((x) => x.id == r.id));
    try {
      await RecordingStore(uid).delete(r);
    } catch (e) {
      debugPrint('Deleting recording failed: $e');
      _load();
    }
  }

  Future<void> _openVideo() async {
    if (RecordingService().isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stop the audio recording first, then record video.')));
      return;
    }
    if (!PurchaseService().isPro) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Video Recording', style: TextStyle(color: Colors.white)),
          content: const Text('Record video of your practice to check posture and technique. Video recording is part of Zyntune Pro.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Not Now', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
              child: const Text('Upgrade to Pro'),
            ),
          ],
        ),
      );
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => VideoRecordScreen(piece: widget.piece)));
  }

  Widget _roundButton({required IconData icon, required Color color, required String label, required VoidCallback onTap, String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 18)]),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          if (badge != null)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _recordCard() {
    final service = RecordingService();
    final recording = service.isRecording;
    final isPro = PurchaseService().isPro;
    final left = RecordingStore.freeLimit - _recordings.where((r) => !r.isVideo).length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (recording ? _recordRed : _purple).withValues(alpha: 0.4)),
      ),
      child: Column(children: [
        if (recording)
          _roundButton(icon: Icons.stop_rounded, color: _recordRed, label: 'Recording… tap to stop', onTap: () => stopRecording(context))
        else
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _roundButton(icon: Icons.mic, color: _recordRed, label: 'Audio', onTap: () => startRecording(context, piece: widget.piece)),
            _roundButton(icon: Icons.videocam, color: _purple, label: 'Video', onTap: _openVideo, badge: isPro ? null : 'PRO'),
          ]),
        const SizedBox(height: 10),
        Text(
          recording
              ? 'Keeps recording if you lock the screen or use other tools'
              : (isPro ? 'Record a lesson or your practice' : '${left.clamp(0, RecordingStore.freeLimit)} of ${RecordingStore.freeLimit} free audio recordings left'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 14),
        const MetronomeControl(),
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
          if (_recordings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Using ${_formatBytes(_bytes)} on this iPhone'
                '${_recordings.any((r) => r.isVideo) ? ' · Videos aren\'t included in iCloud Backup' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          const SizedBox(height: 20),
          if (_recordings.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filterChip(
                    'All',
                    _pieceFilter == null && !_favoritesOnly,
                    () => setState(() {
                          _pieceFilter = null;
                          _favoritesOnly = false;
                        })),
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
            ...visible.map((r) => Dismissible(
                key: ValueKey(r.id),
                // Swipe left to delete, after confirming.
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(r),
                onDismissed: (_) => _delete(r),
                background: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.only(right: 20),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: GestureDetector(
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
                        decoration: BoxDecoration(color: (r.isVideo ? _purple : _recordRed).withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Icon(r.isVideo ? Icons.videocam : Icons.graphic_eq, color: r.isVideo ? _purple : _recordRed, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (r.piece.isNotEmpty && r.pieceLabel != r.title)
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
                ))),
        ],
      ),
    );
  }
}
