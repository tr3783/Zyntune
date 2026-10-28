import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../date_format.dart';
import '../purchase_service.dart';
import '../recordings.dart';
import 'paywall_screen.dart';

/// Deleted recordings, kept for [RecordingStore.trashDays] days so a mistake
/// can be undone. Restore one, delete one now, or empty the whole thing.
class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _recordRed = Color(0xFFE53935);

  List<TrashedRecording> _items = [];
  int _bytes = 0;
  bool _loading = true;

  RecordingStore? get _store {
    final uid = AuthService().currentUser?.uid;
    return uid == null ? null : RecordingStore(uid);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = _store;
    var items = <TrashedRecording>[];
    var bytes = 0;
    try {
      if (store != null) {
        items = await store.loadTrash();
        bytes = await store.trashBytes();
      }
    } catch (e) {
      debugPrint('Loading Recently Deleted failed: $e');
    }
    if (mounted) {
      setState(() {
        _items = items;
        _bytes = bytes;
        _loading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
    return '${(bytes / 1024).round()} KB';
  }

  String _daysLeft(TrashedRecording t) {
    final days = t.daysLeft(DateTime.now());
    return days <= 1 ? 'Deleted for good within a day' : '$days days left';
  }

  /// Free accounts can't restore past the audio recording limit.
  Future<bool> _roomFor(Iterable<TrashedRecording> items) async {
    final store = _store;
    if (store == null) return false;
    if (PurchaseService().isPro) return true;
    final audio = items.where((t) => !t.recording.isVideo).length;
    if (audio == 0 || await store.audioCount() + audio <= RecordingStore.freeLimit) return true;
    if (!mounted) return false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Recording Limit Reached', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Free accounts can keep 3 audio recordings. Delete one from your recordings to make room, or upgrade to Zyntune Pro for unlimited recordings.',
          style: TextStyle(color: Colors.white70),
        ),
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
    return false;
  }

  Future<void> _restore(List<TrashedRecording> items) async {
    final store = _store;
    if (store == null || items.isEmpty || !await _roomFor(items)) return;
    await store.restore(items);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(items.length == 1 ? 'Restored "${items.single.recording.title}".' : 'Restored ${items.length} recordings.'),
        ));
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteNow(TrashedRecording t) async {
    if (!await _confirm('Delete Now?', '"${t.recording.title}" will be permanently deleted. This can\'t be undone.', 'Delete')) return;
    await _store?.deleteForever([t]);
    await _load();
  }

  Future<void> _emptyTrash() async {
    final n = _items.length;
    if (!await _confirm('Empty Recently Deleted?', '${n == 1 ? 'This recording' : 'All $n recordings'} will be permanently deleted. This can\'t be undone.', 'Empty')) return;
    await _store?.emptyTrash();
    await _load();
  }

  void _showActions(TrashedRecording t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(t.recording.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.white),
            title: const Text('Restore', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _restore([t]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Now', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _deleteNow(t);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Recently Deleted', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        actions: [
          if (_items.isNotEmpty) TextButton(onPressed: _emptyTrash, child: const Text('Empty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Deleted recordings are kept here for ${RecordingStore.trashDays} days, then deleted for good.'
                  '${_items.isEmpty ? '' : ' Using ${_formatBytes(_bytes)} on this iPhone.'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nothing here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38)),
                  )
                else ...[
                  ..._items.map((t) {
                    final r = t.recording;
                    return GestureDetector(
                      onTap: () => _showActions(t),
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
                            child: Icon(r.isVideo ? Icons.videocam : Icons.graphic_eq, color: (r.isVideo ? _purple : _recordRed).withValues(alpha: 0.6), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${formatFullDate(r.createdAt)} · ${_daysLeft(t)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ]),
                          ),
                          IconButton(
                            tooltip: 'Restore',
                            icon: const Icon(Icons.restore, color: Colors.white),
                            onPressed: () => _restore([t]),
                          ),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _restore(List.of(_items)),
                    icon: const Icon(Icons.restore),
                    label: Text(_items.length == 1 ? 'Restore' : 'Restore All (${_items.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
