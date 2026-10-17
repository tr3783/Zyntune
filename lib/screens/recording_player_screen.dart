import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../auth_service.dart';
import '../date_format.dart';
import '../recordings.dart';
import 'recording_playback.dart';

/// Plays an audio or video recording, with practice tools: slow down (pitch
/// kept), loop a section, markers with notes, favorite, share, edit, delete.
class RecordingPlayerScreen extends StatefulWidget {
  final Recording recording;
  const RecordingPlayerScreen({super.key, required this.recording});

  @override
  State<RecordingPlayerScreen> createState() => _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends State<RecordingPlayerScreen> {
  static const _purple = Color(0xFF6B21FF);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _pink = Color(0xFFE91E8C);
  static const _teal = Color(0xFF00BFA5);

  late final Recording _r = widget.recording;
  late final RecordingPlayback _player = RecordingPlayback(isVideo: _r.isVideo);
  String? _path;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  double _speed = 1.0;
  Duration? _loopStart;
  Duration? _loopEnd;
  bool _dragging = false;

  RecordingStore? get _store {
    final uid = AuthService().currentUser?.uid;
    return uid == null ? null : RecordingStore(uid);
  }

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: _r.durationMs);
    _player
      ..onPosition = _onPosition
      ..onDuration = (d) {
        if (mounted && d > Duration.zero) setState(() => _duration = d);
      }
      ..onPlayingChanged = (playing) {
        if (mounted) setState(() => _playing = playing);
      }
      ..onComplete = () {
        if (mounted) setState(() => _position = Duration.zero);
      };
    _prepare();
  }

  Future<void> _prepare() async {
    final store = _store;
    if (store == null) return;
    final path = await store.pathFor(_r);
    await _player.open(path);
    if (mounted) setState(() => _path = path);
  }

  void _onPosition(Duration p) {
    // Loop a section: jump back to the start when the end is reached.
    if (_loopStart != null && _loopEnd != null && p >= _loopEnd!) {
      _player.seek(_loopStart!);
      return;
    }
    if (mounted && !_dragging) setState(() => _position = p);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_path == null) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(_speed);
    }
  }

  Future<void> _seek(Duration to) async {
    final clamped = to < Duration.zero ? Duration.zero : (to > _duration ? _duration : to);
    await _player.seek(clamped);
    setState(() => _position = clamped);
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await _player.setSpeed(speed);
  }

  Future<void> _saveChanges() async => _store?.update(_r);

  Future<void> _toggleFavorite() async {
    setState(() => _r.favorite = !_r.favorite);
    await _saveChanges();
  }

  Future<void> _addMarker() async {
    final at = _position;
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Marker at ${_fmt(at)}', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'e.g. Relax the wrist, bar 32 rushed', hintStyle: TextStyle(color: Colors.white30)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (note == null) return;
    setState(() {
      _r.markers.add(RecordingMarker(positionMs: at.inMilliseconds, note: note));
      _r.markers.sort((a, b) => a.positionMs.compareTo(b.positionMs));
    });
    await _saveChanges();
  }

  Future<void> _deleteMarker(RecordingMarker m) async {
    setState(() => _r.markers.remove(m));
    await _saveChanges();
  }

  Future<void> _editDetails() async {
    final title = TextEditingController(text: _r.title);
    final notes = TextEditingController(text: _r.notes);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Edit Recording', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white60))),
          TextField(controller: notes, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Notes', labelStyle: TextStyle(color: Colors.white60))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    setState(() {
      if (title.text.trim().isNotEmpty) _r.title = title.text.trim();
      _r.notes = notes.text.trim();
    });
    await _saveChanges();
  }

  Future<void> _share() async {
    if (_path == null) return;
    // Share with a readable file name instead of the internal one.
    final safeName = _r.title.replaceAll(RegExp(r'[^\w\s\-·]'), '').trim();
    final tmp = await getTemporaryDirectory();
    final ext = _path!.split('.').last;
    final copy = await File(_path!).copy('${tmp.path}/${safeName.isEmpty ? 'Recording' : safeName}.$ext');
    final mime = _r.isVideo ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4') : 'audio/mp4';
    await SharePlus.instance.share(ShareParams(files: [XFile(copy.path, mimeType: mime)], subject: _r.title));
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Delete Recording?', style: TextStyle(color: Colors.white)),
        content: Text('"${_r.title}" will be permanently deleted from this device.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await _player.stop();
    await _store?.delete(_r);
    if (mounted) Navigator.pop(context);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  Widget _pill(String label, bool selected, VoidCallback onTap, {Color color = _pink}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : _purple.withValues(alpha: 0.3)),
          ),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ),
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _purple.withValues(alpha: 0.25)),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final maxMs = _duration.inMilliseconds.toDouble().clamp(1, double.infinity).toDouble();
    final posMs = _position.inMilliseconds.toDouble().clamp(0, maxMs).toDouble();
    final looping = _loopStart != null && _loopEnd != null;

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: Text(_r.isVideo ? 'Video' : 'Recording', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        actions: [
          IconButton(
            tooltip: _r.favorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(_r.favorite ? Icons.star_rounded : Icons.star_border_rounded, color: _r.favorite ? Colors.amber : Colors.white),
            onPressed: _toggleFavorite,
          ),
          IconButton(tooltip: 'Share', icon: const Icon(Icons.ios_share), onPressed: _share),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? _editDetails() : _delete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit name & notes')),
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        children: [
          // Video
          if (_r.isVideo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(color: Colors.black, alignment: Alignment.center, constraints: const BoxConstraints(maxHeight: 420), child: _player.view()),
            ),
            const SizedBox(height: 16),
          ],
          // Title
          Text(_r.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          if (_r.piece.isNotEmpty && _r.pieceLabel != _r.title) Text(_r.pieceLabel, style: const TextStyle(color: _pink, fontSize: 14, fontWeight: FontWeight.w600)),
          Text(formatFullDate(_r.createdAt), style: const TextStyle(color: Colors.white54, fontSize: 13)),
          if (_r.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_r.notes, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
          const SizedBox(height: 20),

          // Transport
          _card(
            child: Column(children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(activeTrackColor: _pink, thumbColor: Colors.white, inactiveTrackColor: Colors.white12, trackHeight: 4),
                child: Slider(
                  min: 0,
                  max: maxMs,
                  value: posMs,
                  onChangeStart: (_) => _dragging = true,
                  onChanged: (v) => setState(() => _position = Duration(milliseconds: v.round())),
                  onChangeEnd: (v) {
                    _dragging = false;
                    _seek(Duration(milliseconds: v.round()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_fmt(_position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(_fmt(_duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(iconSize: 32, color: Colors.white, icon: const Icon(Icons.replay_10), onPressed: () => _seek(_position - const Duration(seconds: 10))),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _purple, boxShadow: [BoxShadow(color: _purple.withValues(alpha: 0.4), blurRadius: 16)]),
                    child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(iconSize: 32, color: Colors.white, icon: const Icon(Icons.forward_10), onPressed: () => _seek(_position + const Duration(seconds: 10))),
              ]),
            ]),
          ),

          // Speed
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Speed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Slow down without changing the pitch', style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                for (final s in [0.5, 0.75, 1.0]) _pill('${s == 1.0 ? '1' : s}×', _speed == s, () => _setSpeed(s)),
              ]),
            ]),
          ),

          // Loop
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Loop a Section', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                looping
                    ? 'Looping ${_fmt(_loopStart!)} – ${_fmt(_loopEnd!)}'
                    : 'Play to where the section starts, tap Start; then where it ends, tap End.',
                style: TextStyle(color: looping ? _teal : Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _pill(_loopStart == null ? 'Start' : 'Start ${_fmt(_loopStart!)}', _loopStart != null, () {
                  setState(() {
                    _loopStart = _position;
                    if (_loopEnd != null && _loopEnd! <= _loopStart!) _loopEnd = null;
                  });
                }, color: _teal),
                _pill(_loopEnd == null ? 'End' : 'End ${_fmt(_loopEnd!)}', _loopEnd != null, () {
                  if (_loopStart == null || _position <= _loopStart!) return;
                  setState(() => _loopEnd = _position);
                  _seek(_loopStart!);
                }, color: _teal),
                if (_loopStart != null || _loopEnd != null)
                  _pill('Clear', false, () => setState(() {
                        _loopStart = null;
                        _loopEnd = null;
                      })),
              ]),
            ]),
          ),

          // Markers
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Markers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                TextButton.icon(
                  onPressed: _addMarker,
                  icon: const Icon(Icons.add, size: 18, color: _pink),
                  label: Text('Add at ${_fmt(_position)}', style: const TextStyle(color: _pink)),
                ),
              ]),
              if (_r.markers.isEmpty)
                const Text('Mark important moments, like your teacher\'s comments in a lesson.', style: TextStyle(color: Colors.white38, fontSize: 12))
              else
                ..._r.markers.map((m) => InkWell(
                      onTap: () async {
                        await _seek(Duration(milliseconds: m.positionMs));
                        if (!_playing) await _togglePlay();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: _pink.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text(_fmt(Duration(milliseconds: m.positionMs)), style: const TextStyle(color: _pink, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(m.note.isEmpty ? '(no note)' : m.note, style: const TextStyle(color: Colors.white, fontSize: 14))),
                          IconButton(
                            tooltip: 'Delete marker',
                            icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                            onPressed: () => _deleteMarker(m),
                          ),
                        ]),
                      ),
                    )),
            ]),
          ),
        ],
      ),
    );
  }
}
