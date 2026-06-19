import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../streak_helper.dart';
import '../timer_service.dart';
import '../practice_objective.dart';
import '../purchase_service.dart';
import '../review_helper.dart';
import '../notification_helper.dart';
import '../widget_service.dart';
import '../firestore_service.dart';
import 'session_card.dart';
import 'paywall_screen.dart';
import 'streak_celebration.dart';

class PracticeSession {
  final String id;
  final String date;
  int durationMinutes;
  String notes;
  String instrument;
  String piece;

  PracticeSession({
    required this.id,
    required this.date,
    required this.durationMinutes,
    required this.notes,
    this.instrument = '',
    this.piece = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'durationMinutes': durationMinutes,
        'notes': notes,
        'instrument': instrument,
        'piece': piece,
      };

  factory PracticeSession.fromJson(Map<String, dynamic> json) =>
      PracticeSession(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: json['date'],
        durationMinutes: json['durationMinutes'],
        notes: json['notes'] ?? '',
        instrument: json['instrument'] ?? '',
        piece: json['piece'] ?? '',
      );
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  Timer? _uiTicker;
  final _timerService = TimerService();
  final List<int> _presets = [5, 10, 15, 20, 30, 45, 60];
  int _selectedPreset = 15;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customMinutesController = TextEditingController();
  List<PracticeSession> _sessions = [];
  List<PracticeObjective> _objectives = [];
  List<String> _instruments = ['Guitar'];
  String _activeInstrument = 'Guitar';
  List<String> _pieceNames = [];
  Set<String> _assignedPieces = {};
  bool _countdownSaveDialogShown = false;
  int _currentStreak = 0;

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSessions();
    _loadObjectives();
    _loadInstruments();
    _loadPieces();
    _loadAssignedPieces();
    _loadStreak();
    _timerService.addListener(_onTimerUpdate);

    // Belt-and-suspenders: also tick the UI every second directly,
    // in case the listener-based update misses ticks after navigation.
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && (_timerService.countdownActive || _timerService.isRunning)) {
        setState(() {});
      }
    });

    _timerService.onCountdownFinished = () {
      if (mounted && !_countdownSaveDialogShown) {
        _countdownSaveDialogShown = true;
        _showCountdownSaveDialog(_timerService.countdownTotal);
      }
    };
  }

  void _onTimerUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_timerService.countdownFinished && !_countdownSaveDialogShown) {
      _countdownSaveDialogShown = true;
      _showCountdownSaveDialog(_timerService.countdownTotal);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _timerService.syncOnResume();
        setState(() {});
        if (_timerService.countdownFinished && !_countdownSaveDialogShown) {
          _countdownSaveDialogShown = true;
          _showCountdownSaveDialog(_timerService.countdownTotal);
        }
      });
    }
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _timerService.removeListener(_onTimerUpdate);
    _notesController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    final data = await StreakHelper.getStreakData();
    if (mounted) setState(() => _currentStreak = data['currentStreak'] ?? 0);
  }

  String _formatDisplayDate(String rawDate) {
    const months = ['Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'Jun.', 'Jul.', 'Aug.', 'Sep.', 'Oct.', 'Nov.', 'Dec.'];
    try {
      final dt = DateTime.parse(rawDate.substring(0, 10));
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return rawDate; }
  }

  Future<void> _loadInstruments() async {
    final prefs = await SharedPreferences.getInstance();
    final instruments = prefs.getStringList('instruments');
    final active = prefs.getString('activeInstrument') ?? 'Guitar';
    final legacy = prefs.getString('instrument') ?? 'Guitar';
    if (mounted) setState(() {
      _instruments = instruments != null && instruments.isNotEmpty ? instruments : [legacy];
      _activeInstrument = _instruments.contains(active) ? active : _instruments.first;
    });
  }

  Future<void> _loadPieces() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('songs') ?? [];
    final names = data.map((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return map['title'] as String? ?? '';
      } catch (_) { return ''; }
    }).where((s) => s.isNotEmpty).toList();
    if (mounted) setState(() => _pieceNames = names);
  }

  Future<void> _loadAssignedPieces() async {
    try {
      final assignments = await FirestoreService().getMyAssignments().first;
      final Set<String> assigned = {};
      for (final a in assignments) {
        final completed = a['completed'] as bool? ?? false;
        if (completed) continue;
        final pieces = (a['pieces'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        for (final p in pieces) {
          final name = (p['piece'] as String?)?.trim();
          if (name != null && name.isNotEmpty) assigned.add(name);
        }
        final legacyPiece = (a['piece'] as String?)?.trim();
        if (legacyPiece != null && legacyPiece.isNotEmpty) assigned.add(legacyPiece);
      }
      if (mounted) setState(() => _assignedPieces = assigned);
    } catch (_) {}
  }

  Future<void> _loadObjectives() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toString().substring(0, 10);
    final objData = prefs.getStringList('objectives_$todayStr') ?? [];
    if (mounted) setState(() => _objectives = objData.map((s) => PracticeObjective.fromJsonString(s)).toList());
  }

  Future<void> _saveObjectives() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toString().substring(0, 10);
    await prefs.setStringList('objectives_$todayStr', _objectives.map((o) => o.toJsonString()).toList());
  }

  void _toggleChecklistItem(PracticeObjective obj, ChecklistItem item) {
    setState(() => item.checked = !item.checked);
    _saveObjectives();
  }

  void _toggleObjectiveComplete(PracticeObjective obj) {
    setState(() => obj.completed = !obj.completed);
    _saveObjectives();
  }

  void _startStopwatch() => _timerService.start();
  void _pauseStopwatch() => _timerService.pause();
  void _resetStopwatch() => _timerService.reset();

  void _stopStopwatch() async {
    _timerService.stop();
    if (_timerService.elapsed > 0) await _showSaveDialog();
    _timerService.reset();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('practiceSessions') ?? [];
    if (mounted) setState(() => _sessions = data.map((s) => PracticeSession.fromJson(jsonDecode(s))).toList().reversed.toList());
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _sessions.reversed.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('practiceSessions', data);
  }

  Future<void> _saveNewSession(String instrument, int durationSeconds, {String notes = '', String piece = ''}) async {
    final minutes = (durationSeconds / 60).floor();
    if (minutes <= 0) return;
    final newSession = PracticeSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now().toString().substring(0, 16),
      durationMinutes: minutes,
      notes: notes,
      instrument: instrument,
      piece: piece,
    );
    setState(() => _sessions.insert(0, newSession));
    await _saveSessions();
    await FirestoreService().saveSession(newSession.toJson());
    await PurchaseService.grandfatherExistingUsers();
    await StreakHelper.updateStreak();
    await _loadStreak();
    await ReviewHelper.maybeRequestReviewAfterSession();
    await WidgetService.updateWidget();

    final prefs = await SharedPreferences.getInstance();
    final streakReminderEnabled = prefs.getBool('streakReminderEnabled') ?? true;
    if (streakReminderEnabled) {
      await NotificationHelper.cancelStreakRiskReminder();
      await NotificationHelper.scheduleStreakRiskReminder(currentStreak: _currentStreak);
    }

    if (mounted) await StreakCelebration.maybeShow(context, _currentStreak);
    HapticFeedback.mediumImpact();
  }

  Widget _buildInstrumentSelector(List<String> selectedRef, StateSetter setDialogState) {
    if (_instruments.length <= 1) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Instrument', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _instruments.map((inst) {
            final isSelected = selectedRef[0] == inst;
            return GestureDetector(
              onTap: () => setDialogState(() => selectedRef[0] = inst),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isSelected ? const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]) : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? Colors.transparent : _purple.withOpacity(0.3)),
                ),
                child: Text(inst, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPieceSelector(List<String> selectedRef, StateSetter setDialogState) {
    // Merge repertoire pieces with assigned pieces (assigned ones first, then any others)
    final combined = <String>[];
    for (final p in _assignedPieces) {
      if (!combined.contains(p)) combined.add(p);
    }
    for (final p in _pieceNames) {
      if (!combined.contains(p)) combined.add(p);
    }
    if (combined.isEmpty) return const SizedBox.shrink();
    final allOptions = ['', ...combined];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Piece (optional)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: allOptions.map((name) {
            final isSelected = selectedRef[0] == name;
            final label = name.isEmpty ? 'Free practice' : name;
            final isAssigned = _assignedPieces.contains(name);
            return GestureDetector(
              onTap: () => setDialogState(() => selectedRef[0] = name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isSelected ? const LinearGradient(colors: [Color(0xFFE91E8C), Color(0xFF9B59B6)]) : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? Colors.transparent : (isAssigned ? const Color(0xFF00BFA5).withOpacity(0.5) : _purple.withOpacity(0.3))),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isAssigned) ...[
                    Icon(Icons.assignment_outlined, size: 12, color: isSelected ? Colors.white : const Color(0xFF00BFA5)),
                    const SizedBox(width: 4),
                  ],
                  Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          }).toList(),
        ),
        if (_assignedPieces.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.assignment_outlined, size: 12, color: Color(0xFF00BFA5)),
            const SizedBox(width: 4),
            Text('= assigned by your teacher', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
          ]),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  void _showSharePrompt({required int minutes, required String piece, required String instrument, required String date}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A4E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Share Your Session?', style: TextStyle(color: Colors.white)),
        content: const Text('Create a shareable card for your practice session.', style: TextStyle(color: Colors.white60, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip', style: TextStyle(color: Colors.white38))),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await SessionCardSharer.shareSession(context: context, minutes: minutes, piece: piece, instrument: instrument, currentStreak: _currentStreak, date: date);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaveDialog() async {
    _notesController.clear();
    final instrumentRef = [_activeInstrument];
    final pieceRef = [''];
    bool saved = false;
    int savedMinutes = 0;
    String savedPiece = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A0A4E),
          title: const Text('Save Session', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _purple.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(_formatTime(_timerService.elapsed), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ]),
              ),
              const SizedBox(height: 16),
              _buildInstrumentSelector(instrumentRef, setDialogState),
              _buildPieceSelector(pieceRef, setDialogState),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: _notesController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  hintText: 'What did you work on?',
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                ),
                maxLines: 3,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Discard', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () async {
                savedMinutes = (_timerService.elapsed / 60).floor();
                savedPiece = pieceRef[0];
                await _saveNewSession(instrumentRef[0], _timerService.elapsed, notes: _notesController.text.trim(), piece: pieceRef[0]);
                saved = true;
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved && savedMinutes > 0 && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final isPro = PurchaseService().isPro;
      if (isPro && (prefs.getBool('sharePromptEnabled') ?? true)) {
        _showSharePrompt(minutes: savedMinutes, piece: savedPiece, instrument: _activeInstrument, date: DateTime.now().toString());
      }
    }
  }

  Future<void> _showCountdownSaveDialog(int totalSeconds) async {
    final notesController = TextEditingController();
    final instrumentRef = [_activeInstrument];
    final pieceRef = [''];
    final minutes = (totalSeconds / 60).floor();
    bool saved = false;
    String savedPiece = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A0A4E),
          title: const Text('🎉 Session Complete!', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text('$minutes min', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ]),
              ),
              const SizedBox(height: 16),
              _buildInstrumentSelector(instrumentRef, setDialogState),
              _buildPieceSelector(pieceRef, setDialogState),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: notesController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  hintText: 'What did you work on?',
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                ),
                maxLines: 3,
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () { _timerService.resetCountdown(); _countdownSaveDialogShown = false; Navigator.pop(context); },
              child: const Text('Discard', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                savedPiece = pieceRef[0];
                await _saveNewSession(instrumentRef[0], totalSeconds, notes: notesController.text.trim(), piece: pieceRef[0]);
                saved = true;
                _timerService.resetCountdown();
                _countdownSaveDialogShown = false;
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved && minutes > 0 && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final isPro = PurchaseService().isPro;
      if (isPro && (prefs.getBool('sharePromptEnabled') ?? true)) {
        _showSharePrompt(minutes: minutes, piece: savedPiece, instrument: _activeInstrument, date: DateTime.now().toString());
      }
    }
  }

  void _showEditDialog(PracticeSession session) {
    final editNotesController = TextEditingController(text: session.notes);
    final editMinutesController = TextEditingController(text: session.durationMinutes.toString());
    final instrumentRef = [session.instrument.isNotEmpty ? session.instrument : _activeInstrument];
    final pieceRef = [session.piece];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Edit Session', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_formatDisplayDate(session.date), style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 12),
              TextField(
                controller: editMinutesController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Duration (minutes)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                  prefixIcon: const Icon(Icons.timer, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              _buildInstrumentSelector(instrumentRef, setDialogState),
              _buildPieceSelector(pieceRef, setDialogState),
              TextField(
                textCapitalization: TextCapitalization.sentences,
                controller: editNotesController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Notes',
                  labelStyle: const TextStyle(color: Colors.white60),
                  hintText: 'What did you work on?',
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _purple.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _purple)),
                ),
                maxLines: 3,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () async {
                final mins = int.tryParse(editMinutesController.text) ?? session.durationMinutes;
                setState(() {
                  session.durationMinutes = mins;
                  session.notes = editNotesController.text.trim();
                  session.instrument = instrumentRef[0];
                  session.piece = pieceRef[0];
                });
                await _saveSessions();
                await FirestoreService().updateSession(session.toJson());
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSession(PracticeSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Delete the ${session.durationMinutes} min session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _sessions.removeWhere((s) => s.id == session.id));
      await _saveSessions();
      await FirestoreService().deleteSession(session.id);
    }
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  IconData _getInstrumentIcon(String instrument) {
    switch (instrument.toLowerCase()) {
      case 'piano': return Icons.piano;
      case 'drums': return Icons.album;
      case 'voice': return Icons.mic;
      default: return Icons.music_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _timerService.elapsed;
    final isRunning = _timerService.isRunning;
    final isPaused = _timerService.isPaused;
    final countdownActive = _timerService.countdownActive;
    final countdownFinished = _timerService.countdownFinished;
    final countdownRemaining = _timerService.countdownRemaining;
    final countdownProgress = _timerService.countdownProgress;

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Practice Timer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- TODAY'S OBJECTIVES ---
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Today's Objectives", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                GestureDetector(
                  onTap: _loadObjectives,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _purple.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.3))), child: const Row(children: [Icon(Icons.refresh, size: 14, color: Color(0xFF9B59B6)), SizedBox(width: 4), Text('Refresh', style: TextStyle(fontSize: 12, color: Color(0xFF9B59B6), fontWeight: FontWeight.w600))])),
                ),
              ]),
              const SizedBox(height: 10),
              if (_objectives.isEmpty)
                Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(16), border: Border.all(color: _purple.withOpacity(0.3))), child: const Text('No objectives set for today.\nAdd them on the home screen!', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white54)))
              else
                ..._objectives.map((obj) => _buildObjectiveCard(obj)),
              const SizedBox(height: 24),

              // --- STOPWATCH ---
              const Text('Stopwatch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: isRunning ? [const Color(0xFF00695C), const Color(0xFF00897B)] : isPaused ? [const Color(0xFF4A3000), const Color(0xFF6D4600)] : [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isRunning ? Colors.teal.withOpacity(0.6) : isPaused ? Colors.orange.withOpacity(0.6) : _purple.withOpacity(0.4), width: 1.5),
                  boxShadow: [BoxShadow(color: isRunning ? Colors.teal.withOpacity(0.3) : _purple.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Column(children: [
                  Text(_formatTime(elapsed), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(isRunning ? '⏱ Recording...' : isPaused ? '⏸ Paused' : 'Tap Start to begin', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: isRunning ? _pauseStopwatch : _startStopwatch, icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24), label: Text(isRunning ? 'Pause' : 'Start', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: isRunning ? Colors.orange : const Color(0xFF00BFA5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4))),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(onPressed: (isRunning || isPaused) ? _stopStopwatch : null, icon: const Icon(Icons.stop_rounded, size: 20), label: const Text('Stop & Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4444), foregroundColor: Colors.white, disabledBackgroundColor: Colors.white.withOpacity(0.1), disabledForegroundColor: Colors.white30, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton.icon(onPressed: _resetStopwatch, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('Reset', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), style: ElevatedButton.styleFrom(backgroundColor: _cardBg, foregroundColor: const Color(0xFF9B59B6), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _purple.withOpacity(0.4)))))),
                  ]),
                ]),
              ),
              const SizedBox(height: 24),

              // --- COUNTDOWN ---
              const Text('Countdown Timer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _presets.map((min) {
                  final isSelected = _selectedPreset == min;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () { setState(() => _selectedPreset = min); _timerService.setCountdownDuration(min); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(gradient: isSelected ? const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]) : null, color: isSelected ? null : _cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? Colors.transparent : _purple.withOpacity(0.3)), boxShadow: isSelected ? [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : []),
                        child: Text('$min min', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : const Color(0xFF9B59B6))),
                      ),
                    ),
                  );
                }).toList()),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Custom: ', style: TextStyle(fontSize: 14, color: Colors.white70)),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _customMinutesController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(hintText: 'min', hintStyle: const TextStyle(color: Colors.white30), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purple.withOpacity(0.4))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _purple.withOpacity(0.4))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _purple)), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                    onSubmitted: (val) {
                      final mins = int.tryParse(val);
                      if (mins != null && mins > 0) { setState(() => _selectedPreset = -1); _timerService.setCountdownDuration(mins); FocusScope.of(context).unfocus(); }
                    },
                    onTapOutside: (_) {
                      final mins = int.tryParse(_customMinutesController.text);
                      if (mins != null && mins > 0) { setState(() => _selectedPreset = -1); _timerService.setCountdownDuration(mins); }
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                const Text(' minutes', style: TextStyle(fontSize: 14, color: Colors.white70)),
              ]),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: countdownFinished ? [const Color(0xFF00695C), const Color(0xFF00897B)] : countdownActive ? [const Color(0xFF4A2600), const Color(0xFF6D3800)] : [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: countdownFinished ? Colors.green.withOpacity(0.6) : countdownActive ? Colors.orange.withOpacity(0.6) : _purple.withOpacity(0.4), width: 1.5),
                  boxShadow: [BoxShadow(color: countdownFinished ? Colors.green.withOpacity(0.25) : countdownActive ? Colors.orange.withOpacity(0.25) : _purple.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Column(children: [
                  Stack(alignment: Alignment.center, children: [
                    SizedBox(width: 150, height: 150, child: CircularProgressIndicator(value: countdownProgress, strokeWidth: 10, backgroundColor: Colors.white.withOpacity(0.1), color: countdownFinished ? Colors.greenAccent : Colors.orange)),
                    Column(children: [
                      Text(countdownFinished ? '🎉' : '⏳', style: const TextStyle(fontSize: 36)),
                      Text(countdownFinished ? 'Done!' : _formatTime(countdownRemaining), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Colors.white)),
                    ]),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: countdownActive ? _timerService.pauseCountdown : _timerService.startCountdown, icon: Icon(countdownActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24), label: Text(countdownActive ? 'Pause' : 'Start', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), style: ElevatedButton.styleFrom(backgroundColor: countdownActive ? Colors.orange : const Color(0xFF00BFA5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4))),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _timerService.resetCountdown, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('Reset', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), style: ElevatedButton.styleFrom(backgroundColor: _cardBg, foregroundColor: const Color(0xFF9B59B6), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _purple.withOpacity(0.4)))))),
                ]),
              ),
              const SizedBox(height: 28),

              // --- Recent Sessions ---
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Recent Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Swipe to delete • Tap to edit', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
              ]),
              const SizedBox(height: 12),

              _sessions.isEmpty
                  ? Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.3))), child: const Column(children: [Icon(Icons.music_note_outlined, color: Colors.white30, size: 36), SizedBox(height: 8), Text('No sessions yet.\nStart practicing!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 14))]))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final displayDate = _formatDisplayDate(session.date);
                        return Dismissible(
                          key: Key(session.id),
                          direction: DismissDirection.endToStart,
                          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete, color: Colors.white)),
                          onDismissed: (_) => _deleteSession(session),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(16), border: Border.all(color: _purple.withOpacity(0.25))),
                            child: Row(children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _purple.withOpacity(0.2), shape: BoxShape.circle), child: Icon(_getInstrumentIcon(session.instrument), color: const Color(0xFF9B59B6), size: 18)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text('${session.durationMinutes} min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  if (session.instrument.isNotEmpty) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(session.instrument, style: const TextStyle(color: Color(0xFF9B59B6), fontSize: 10)))],
                                ]),
                                if (session.piece.isNotEmpty) Text(session.piece, style: const TextStyle(color: Color(0xFFE91E8C), fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(session.notes.isEmpty ? displayDate : '$displayDate • ${session.notes}', style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ])),
                              IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9B59B6)), onPressed: () => _showEditDialog(session)),
                              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () => _deleteSession(session)),
                            ]),
                          ),
                        );
                      }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectiveCard(PracticeObjective obj) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: obj.completed ? [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.08)] : [_cardBg, _cardBg2]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: obj.completed ? Colors.green.withOpacity(0.4) : _purple.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(onTap: () => _toggleObjectiveComplete(obj), child: Icon(obj.completed ? Icons.check_circle : Icons.radio_button_unchecked, color: obj.completed ? Colors.green : const Color(0xFF9B59B6), size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(obj.pieceName.isEmpty ? 'Free Practice' : obj.pieceName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: obj.completed ? Colors.green : Colors.white, decoration: obj.completed ? TextDecoration.lineThrough : null)),
            if (obj.section.isNotEmpty) Text(obj.section, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ])),
          if (obj.targetMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, size: 11, color: Color(0xFF00BFA5)),
                const SizedBox(width: 3),
                Text('${obj.targetMinutes} min', style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        if (obj.checklistItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...obj.checklistItems.map((item) => Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 6),
            child: GestureDetector(
              onTap: () => _toggleChecklistItem(obj, item),
              child: Row(children: [
                Icon(item.checked ? Icons.check_circle_outline : Icons.circle_outlined, size: 16, color: item.checked ? Colors.green : const Color(0xFF9B59B6).withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(child: Text(item.text, style: TextStyle(fontSize: 12, color: item.checked ? Colors.white30 : Colors.white70, decoration: item.checked ? TextDecoration.lineThrough : null))),
              ]),
            ),
          )),
        ],
      ]),
    );
  }
}