import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../streak_helper.dart';
import '../practice_objective.dart';
import 'metronome_screen.dart';
import 'timer_screen.dart';
import 'goals_screen.dart';
import 'songs_screen.dart';
import 'stats_screen.dart';
import 'tuner_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _totalSessions = 0;
  int _totalMinutes = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _todayMinutes = 0;
  int _dailyGoalMinutes = 30;
  String _todayDate = '';
  String _userName = 'Musician';
  String _instrument = 'Guitar';
  List<PracticeObjective> _objectives = [];
  List<String> _pieceNames = [];

  final List<Map<String, dynamic>> _allTips = [
    {'tip': 'Practicing 20 minutes daily is more effective than 2 hours once a week.', 'color': Colors.deepPurple},
    {'tip': 'Always start new pieces slowly. Speed comes naturally with repetition.', 'color': Colors.teal},
    {'tip': 'Isolate difficult passages and repeat them in small chunks.', 'color': Colors.orange},
    {'tip': 'Record yourself playing — you\'ll hear things you miss while playing.', 'color': Colors.pink},
    {'tip': 'Practice hands separately before putting them together on piano pieces.', 'color': Colors.blue},
    {'tip': 'Use a metronome even on slow practice — consistency builds muscle memory.', 'color': Colors.green},
    {'tip': 'Take breaks every 25-30 minutes. Your brain consolidates learning during rest.', 'color': Colors.indigo},
    {'tip': 'Focus on the transition between difficult sections, not just the hard part itself.', 'color': Colors.deepOrange},
    {'tip': 'Sing or hum the melody before playing it — internalize the music first.', 'color': Colors.purple},
    {'tip': 'Practice in different keys or positions to deepen your understanding.', 'color': Colors.cyan},
    {'tip': 'End every practice session on something you do well — finish positively!', 'color': Colors.amber},
    {'tip': 'Listen to professional recordings of pieces you\'re learning for inspiration.', 'color': Colors.red},
    {'tip': 'Memorize small sections at a time — 4 bars is easier than a whole page.', 'color': Colors.teal},
    {'tip': 'Practice the ending of a piece first — you\'ll always know how to finish!', 'color': Colors.deepPurple},
    {'tip': 'Pay attention to dynamics. Playing loud and soft expressively sets great musicians apart.', 'color': Colors.blue},
    {'tip': 'Mental practice counts — visualize fingering and passages away from your instrument.', 'color': Colors.green},
    {'tip': 'Set a specific goal for each practice session before you begin.', 'color': Colors.orange},
    {'tip': 'Practice sight-reading something new every day — even just a few lines.', 'color': Colors.pink},
    {'tip': 'Tension is the enemy of technique. Check your shoulders, arms, and hands regularly.', 'color': Colors.indigo},
    {'tip': 'Celebrate small wins — every passage mastered is real progress!', 'color': Colors.amber},
  ];

  List<Map<String, dynamic>> get _todaysTips {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    final startIndex = (dayOfYear * 3) % _allTips.length;
    return [
      _allTips[startIndex % _allTips.length],
      _allTips[(startIndex + 1) % _allTips.length],
      _allTips[(startIndex + 2) % _allTips.length],
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _todayDate = _formatDate(DateTime.now());
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('practiceSessions') ?? [];
    int totalMins = 0;
    int todayMins = 0;
    final todayStr = DateTime.now().toString().substring(0, 10);

    for (final s in data) {
      final match = RegExp(r'"durationMinutes":(\d+)').firstMatch(s);
      final mins = int.tryParse(match?.group(1) ?? '0') ?? 0;
      totalMins += mins;
      if (s.contains(todayStr)) todayMins += mins;
    }

    final streakData = await StreakHelper.getStreakData();
    final userName = prefs.getString('userName') ?? 'Musician';
    final instrument = prefs.getString('instrument') ?? 'Guitar';
    final dailyGoal = prefs.getInt('dailyGoalMinutes') ?? 30;

    final todayKey = 'objectives_$todayStr';
    final objData = prefs.getStringList(todayKey) ?? [];
    final objectives = objData
        .map((s) => PracticeObjective.fromJsonString(s))
        .toList();

    final piecesData = prefs.getStringList('songs') ?? [];
    final pieceNames = piecesData.map((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return map['title'] as String? ?? '';
      } catch (_) {
        return '';
      }
    }).where((s) => s.isNotEmpty).toList();

    setState(() {
      _totalSessions = data.length;
      _totalMinutes = totalMins;
      _todayMinutes = todayMins;
      _dailyGoalMinutes = dailyGoal;
      _currentStreak = streakData['currentStreak'] ?? 0;
      _longestStreak = streakData['longestStreak'] ?? 0;
      _userName = userName;
      _instrument = instrument;
      _objectives = objectives;
      _pieceNames = pieceNames.cast<String>();
    });
  }

  Future<void> _saveObjectives() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toString().substring(0, 10);
    final todayKey = 'objectives_$todayStr';
    await prefs.setStringList(todayKey,
        _objectives.map((o) => o.toJsonString()).toList());
  }

  void _showAddObjectiveDialog() {
    String selectedPiece = '';
    final sectionController = TextEditingController();
    final checklistController = TextEditingController();
    List<String> checklistItems = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Practice Objective'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedPiece.isEmpty ? null : selectedPiece,
                  decoration: const InputDecoration(
                    labelText: 'Piece (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.music_note),
                  ),
                  hint: const Text('Select a piece'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Free practice')),
                    ..._pieceNames.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (val) => setDialogState(() => selectedPiece = val ?? ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sectionController,
                  onTapOutside: (_) {},
                  decoration: const InputDecoration(
                    labelText: 'Section / Movement',
                    hintText: 'e.g. Measures 24-32, Chorus',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bookmark),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Checklist Items',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...checklistItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_box_outline_blank, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setDialogState(
                                () => checklistItems.remove(item)),
                          ),
                        ],
                      ),
                    )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: checklistController,
                        decoration: const InputDecoration(
                          hintText: 'Add item...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            setDialogState(() {
                              checklistItems.add(val.trim());
                              checklistController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: Color(0xFF6B21FF)),
                      onPressed: () {
                        if (checklistController.text.trim().isNotEmpty) {
                          setDialogState(() {
                            checklistItems.add(checklistController.text.trim());
                            checklistController.clear();
                          });
                        }
                      },
                    ),
                  ],
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
              onPressed: () {
                final obj = PracticeObjective(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  pieceName: selectedPiece,
                  section: sectionController.text.trim(),
                  checklistItems: checklistItems
                      .map((text) => ChecklistItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            text: text,
                          ))
                      .toList(),
                );
                setState(() => _objectives.add(obj));
                _saveObjectives();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleChecklistItem(PracticeObjective obj, ChecklistItem item) {
    setState(() => item.checked = !item.checked);
    _saveObjectives();
  }

  void _toggleObjectiveComplete(PracticeObjective obj) {
    setState(() => obj.completed = !obj.completed);
    _saveObjectives();
  }

  void _deleteObjective(PracticeObjective obj) {
    setState(() => _objectives.remove(obj));
    _saveObjectives();
  }

  void _showSetGoalDialog() {
    int tempGoal = _dailyGoalMinutes;
    final customController = TextEditingController(text: '$_dailyGoalMinutes');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Daily Practice Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [15, 20, 30, 45, 60, 90]
                    .map((min) => GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              tempGoal = min;
                              customController.text = '$min';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: tempGoal == min
                                  ? const Color(0xFF6B21FF)
                                  : const Color(0xFF6B21FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF6B21FF).withOpacity(0.4)),
                            ),
                            child: Text(
                              '$min min',
                              style: TextStyle(
                                color: tempGoal == min
                                    ? Colors.white
                                    : const Color(0xFF6B21FF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Custom: ', style: TextStyle(fontSize: 15)),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: customController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                      ),
                      onChanged: (val) {
                        final mins = int.tryParse(val);
                        if (mins != null && mins > 0) {
                          setDialogState(() => tempGoal = mins);
                        }
                      },
                    ),
                  ),
                  const Text(' minutes', style: TextStyle(fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Current goal: $tempGoal minutes/day',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B21FF),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('dailyGoalMinutes', tempGoal);
                setState(() => _dailyGoalMinutes = tempGoal);
                customController.dispose();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B21FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('Set Goal'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getInstrumentIcon(String instrument) {
    switch (instrument.toLowerCase()) {
      case 'guitar':
      case 'bass':
        return Icons.music_note;
      case 'piano':
        return Icons.piano;
      case 'drums':
        return Icons.album;
      case 'voice':
        return Icons.mic;
      case 'violin':
      case 'viola':
      case 'cello':
        return Icons.queue_music;
      default:
        return Icons.music_note;
    }
  }

  double get _dailyProgress {
    if (_dailyGoalMinutes == 0) return 0;
    return (_todayMinutes / _dailyGoalMinutes).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tips = _todaysTips;
    final goalReached = _todayMinutes >= _dailyGoalMinutes;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D1A)
          : const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: const Text(
          'Zyntune',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6B21FF), Color(0xFF9B59B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadData()),
          ),
          IconButton(
            icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: Colors.white),
            onPressed: () => ZyntuneApp.of(context)?.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Hero Welcome Card ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B21FF), Color(0xFF9B59B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B21FF).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_todayDate,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            'Hey, $_userName! 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(_getInstrumentIcon(_instrument),
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(_instrument,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatPill(
                            label: 'Sessions',
                            value: '$_totalSessions',
                            icon: Icons.event_note_outlined),
                        _Divider(),
                        _StatPill(
                            label: 'Minutes',
                            value: '$_totalMinutes',
                            icon: Icons.timer_outlined),
                        _Divider(),
                        _StatPill(
                            label: 'Hours',
                            value: (_totalMinutes / 60).toStringAsFixed(1),
                            icon: Icons.star_outline),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Daily Goal Card — full gradient like other cards ---
            GestureDetector(
              onTap: _showSetGoalDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: goalReached
                        ? [
                            const Color(0xFF00C853),
                            const Color(0xFF69F0AE).withOpacity(0.8),
                          ]
                        : [
                            const Color(0xFF1A0A4E),
                            const Color(0xFF2D1B69),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: goalReached
                        ? Colors.green.withOpacity(0.6)
                        : const Color(0xFF6B21FF).withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: goalReached
                          ? Colors.green.withOpacity(0.3)
                          : const Color(0xFF6B21FF).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _dailyProgress,
                            strokeWidth: 7,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            color: Colors.white,
                          ),
                          Text(
                            goalReached
                                ? '✓'
                                : '${(_dailyProgress * 100).round()}%',
                            style: TextStyle(
                              fontSize: goalReached ? 22 : 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goalReached ? '🎉 Goal Reached!' : "Today's Goal",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_todayMinutes / $_dailyGoalMinutes min',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _dailyProgress,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              color: Colors.white,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goalReached
                                ? 'Amazing work today!'
                                : '${_dailyGoalMinutes - _todayMinutes} min remaining',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined,
                        size: 16, color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Streak Card ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Practice Streak',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$_currentStreak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6, left: 4),
                              child: Text('days',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                            ),
                          ],
                        ),
                        Text(
                          _currentStreak == 0
                              ? 'Start your streak today!'
                              : _currentStreak == 1
                                  ? 'Great start! Keep going!'
                                  : 'You\'re on fire! 🔥',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: Colors.white, size: 26),
                        const SizedBox(height: 4),
                        Text('$_longestStreak',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            )),
                        const Text('Best',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Today's Objectives ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Objectives",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: _showAddObjectiveDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B21FF), Color(0xFF9B59B6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B21FF).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_objectives.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A0A4E), Color(0xFF2D1B69)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF6B21FF).withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B21FF).withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.playlist_add,
                          size: 28, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "What will you practice today?",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap Add to set your practice objectives',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              )
            else
              ..._objectives.map((obj) => _ObjectiveCard(
                    objective: obj,
                    onToggleComplete: () => _toggleObjectiveComplete(obj),
                    onToggleItem: (item) => _toggleChecklistItem(obj, item),
                    onDelete: () => _deleteObjective(obj),
                  )),
            const SizedBox(height: 20),

            // --- Tools Grid ---
            const Text('Tools',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
              children: [
                _ToolButton(
                  icon: Icons.music_note,
                  label: 'Metronome',
                  color: const Color(0xFF6B21FF),
                  onTap: () => _navigate(context, const MetronomeScreen()),
                ),
                _ToolButton(
                  icon: Icons.timer_outlined,
                  label: 'Timer',
                  color: const Color(0xFF00BFA5),
                  onTap: () => _navigate(context, const TimerScreen()),
                ),
                _ToolButton(
                  icon: Icons.flag_outlined,
                  label: 'Goals',
                  color: const Color(0xFFFF6B35),
                  onTap: () => _navigate(context, const GoalsScreen()),
                ),
                _ToolButton(
                  icon: Icons.library_music_outlined,
                  label: 'Repertoire',
                  color: const Color(0xFFE91E8C),
                  onTap: () => _navigate(context, const SongsScreen()),
                ),
                _ToolButton(
                  icon: Icons.bar_chart,
                  label: 'Stats',
                  color: const Color(0xFF2196F3),
                  onTap: () => _navigate(context, const StatsScreen()),
                ),
                _ToolButton(
                  icon: Icons.graphic_eq,
                  label: 'Tuner',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _navigate(context, const TunerScreen()),
                ),
                _ToolButton(
                  icon: Icons.note_alt_outlined,
                  label: 'Notes',
                  color: const Color(0xFF5C6BC0),
                  onTap: () => _navigate(context, const NotesScreen()),
                ),
                _ToolButton(
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendar',
                  color: const Color(0xFF9C27B0),
                  onTap: () => _navigate(context, const CalendarScreen()),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Tips ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tips of the Day',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B21FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Daily',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B21FF),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _TipCard(tip: tips[0]['tip'], color: tips[0]['color']),
            const SizedBox(height: 8),
            _TipCard(tip: tips[1]['tip'], color: tips[1]['color']),
            const SizedBox(height: 8),
            _TipCard(tip: tips[2]['tip'], color: tips[2]['color']),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadData());
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Colors.white.withOpacity(0.2),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectiveCard extends StatelessWidget {
  final PracticeObjective objective;
  final VoidCallback onToggleComplete;
  final Function(ChecklistItem) onToggleItem;
  final VoidCallback onDelete;

  const _ObjectiveCard({
    required this.objective,
    required this.onToggleComplete,
    required this.onToggleItem,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: objective.completed
            ? Colors.green.withOpacity(0.08)
            : isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: objective.completed
              ? Colors.green.withOpacity(0.4)
              : const Color(0xFF6B21FF).withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onToggleComplete,
                child: Icon(
                  objective.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: objective.completed
                      ? Colors.green
                      : const Color(0xFF6B21FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      objective.pieceName.isEmpty
                          ? 'Free Practice'
                          : objective.pieceName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: objective.completed
                            ? Colors.green
                            : colorScheme.onSurface,
                        decoration: objective.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (objective.section.isNotEmpty)
                      Text(
                        objective.section,
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.55)),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: Colors.red.withOpacity(0.7)),
                onPressed: onDelete,
              ),
            ],
          ),
          if (objective.checklistItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...objective.checklistItems.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 6),
                  child: GestureDetector(
                    onTap: () => onToggleItem(item),
                    child: Row(
                      children: [
                        Icon(
                          item.checked
                              ? Icons.check_circle_outline
                              : Icons.circle_outlined,
                          size: 16,
                          color: item.checked
                              ? Colors.green
                              : const Color(0xFF6B21FF).withOpacity(0.5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 13,
                              color: item.checked
                                  ? colorScheme.onSurface.withOpacity(0.35)
                                  : colorScheme.onSurface,
                              decoration: item.checked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String tip;
  final Color color;

  const _TipCard({required this.tip, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_outline, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}