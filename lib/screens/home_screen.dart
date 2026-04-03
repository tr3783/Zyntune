import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../streak_helper.dart';
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

    setState(() {
      _totalSessions = data.length;
      _totalMinutes = totalMins;
      _todayMinutes = todayMins;
      _dailyGoalMinutes = dailyGoal;
      _currentStreak = streakData['currentStreak'] ?? 0;
      _longestStreak = streakData['longestStreak'] ?? 0;
      _userName = userName;
      _instrument = instrument;
    });
  }

  void _showSetGoalDialog() {
    int tempGoal = _dailyGoalMinutes;
    final customController = TextEditingController(
        text: '$_dailyGoalMinutes');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Daily Practice Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick presets
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
                                  ? Colors.teal
                                  : Colors.teal.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.teal
                                    .withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              '$min min',
                              style: TextStyle(
                                color: tempGoal == min
                                    ? Colors.white
                                    : Colors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Custom input
              Row(
                children: [
                  const Text('Custom: ',
                      style: TextStyle(fontSize: 15)),
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
                  const Text(' minutes',
                      style: TextStyle(fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Current goal: $tempGoal minutes/day',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
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
                final prefs =
                    await SharedPreferences.getInstance();
                await prefs.setInt(
                    'dailyGoalMinutes', tempGoal);
                setState(() => _dailyGoalMinutes = tempGoal);
                customController.dispose();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
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
      appBar: AppBar(
        title: const Text(
          'Zyntune',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ).then((_) => _loadData()),
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () =>
                PracticePilotApp.of(context)?.toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Header Card ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.deepPurple.shade800, Colors.purple.shade900]
                      : [Colors.deepPurple.shade300, Colors.purple.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_todayDate,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome, $_userName!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_getInstrumentIcon(_instrument),
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(_instrument,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _QuickStat(
                          label: 'Sessions',
                          value: '$_totalSessions',
                          icon: Icons.event_note),
                      const SizedBox(width: 20),
                      _QuickStat(
                          label: 'Minutes',
                          value: '$_totalMinutes',
                          icon: Icons.timer),
                      const SizedBox(width: 20),
                      _QuickStat(
                          label: 'Hours',
                          value: (_totalMinutes / 60).toStringAsFixed(1),
                          icon: Icons.star),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- Daily Goal Card ---
            GestureDetector(
              onTap: _showSetGoalDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: goalReached
                      ? Colors.green.withOpacity(0.1)
                      : Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: goalReached
                        ? Colors.green.withOpacity(0.4)
                        : Colors.teal.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _dailyProgress,
                            strokeWidth: 8,
                            backgroundColor:
                                Colors.teal.withOpacity(0.2),
                            color: goalReached
                                ? Colors.green
                                : Colors.teal,
                          ),
                          Text(
                            goalReached
                                ? 'Done!'
                                : '${(_dailyProgress * 100).round()}%',
                            style: TextStyle(
                              fontSize: goalReached ? 10 : 12,
                              fontWeight: FontWeight.bold,
                              color: goalReached
                                  ? Colors.green
                                  : Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            goalReached
                                ? 'Daily Goal Reached!'
                                : 'Today\'s Practice Goal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: goalReached
                                  ? Colors.green
                                  : Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_todayMinutes / $_dailyGoalMinutes min today',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (!goalReached)
                            Text(
                              '${_dailyGoalMinutes - _todayMinutes} min remaining',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.teal),
                            ),
                          if (goalReached)
                            const Text(
                              'Amazing work today!',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.green),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit,
                        size: 16,
                        color: colorScheme.onSurface.withOpacity(0.3)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- Streak Card ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.orange.shade800,
                          Colors.deepOrange.shade900]
                      : [Colors.orange.shade300,
                          Colors.deepOrange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text('Practice Streak',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$_currentStreak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Padding(
                              padding:
                                  EdgeInsets.only(bottom: 6),
                              child: Text(' days',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16)),
                            ),
                          ],
                        ),
                        Text(
                          _currentStreak == 0
                              ? 'Start your streak today!'
                              : _currentStreak == 1
                                  ? 'Great start! Keep going!'
                                  : 'Amazing consistency!',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: Colors.white, size: 28),
                        const SizedBox(height: 4),
                        Text('$_longestStreak',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            )),
                        const Text('Best',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Tools Section ---
            Text('Tools',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                )),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.music_note,
                    label: 'Metronome',
                    subtitle: 'BPM & tempo',
                    color: Colors.deepPurple,
                    onTap: () => _navigate(
                        context, const MetronomeScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.timer,
                    label: 'Timer',
                    subtitle: 'Track sessions',
                    color: Colors.teal,
                    onTap: () =>
                        _navigate(context, const TimerScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.flag,
                    label: 'Goals',
                    subtitle: 'Daily targets',
                    color: Colors.orange,
                    onTap: () =>
                        _navigate(context, const GoalsScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.library_music,
                    label: 'Repertoire',
                    subtitle: 'My pieces',
                    color: Colors.pink,
                    onTap: () =>
                        _navigate(context, const SongsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.bar_chart,
                    label: 'Stats',
                    subtitle: 'Progress charts',
                    color: Colors.blue,
                    onTap: () =>
                        _navigate(context, const StatsScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.graphic_eq,
                    label: 'Tuner',
                    subtitle: 'Check pitch',
                    color: Colors.green,
                    onTap: () =>
                        _navigate(context, const TunerScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.note_alt,
                    label: 'Lesson Notes',
                    subtitle: 'Quick scratchpad',
                    color: Colors.indigo,
                    onTap: () =>
                        _navigate(context, const NotesScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    icon: Icons.calendar_month,
                    label: 'Calendar',
                    subtitle: 'Practice history',
                    color: Colors.deepPurple,
                    onTap: () => _navigate(
                        context, const CalendarScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Today's Tips ---
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text('Tips of the Day',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    )),
                Text('Updates daily',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface
                          .withOpacity(0.4),
                    )),
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
    Navigator.push(
            context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadData());
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11)),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}