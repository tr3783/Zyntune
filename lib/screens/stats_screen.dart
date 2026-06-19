import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import '../purchase_service.dart';
import 'paywall_screen.dart';

// --- Achievement model ---
class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  bool unlocked;
  String? unlockedDate;

  Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    this.unlocked = false,
    this.unlockedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'unlocked': unlocked,
        'unlockedDate': unlockedDate,
      };

  factory Achievement.fromJson(Achievement base, Map<String, dynamic> json) {
    return Achievement(
      id: base.id,
      emoji: base.emoji,
      title: base.title,
      description: base.description,
      unlocked: json['unlocked'] ?? false,
      unlockedDate: json['unlockedDate'],
    );
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  int _totalMinutes = 0;
  int _totalSessions = 0;
  double _avgMinutes = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  String _userName = 'Musician';
  List<String> _instruments = [];
  String _viewMode = 'weekly';
  String _filterInstrument = 'All';
  int _pieceCount = 0;
  int _goalsCompleted = 0;

  Map<String, int> _pieceMinutes = {};
  int _totalPieceMinutes = 0;
  List<Achievement> _achievements = [];

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  static const List<Color> _instrumentColors = [
    Color(0xFF6B21FF), Color(0xFF00BFA5), Color(0xFFFF6B35), Color(0xFFE91E8C),
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFFFD700), Color(0xFF9C27B0),
  ];

  static const List<Color> _pieceColors = [
    Color(0xFF00BFA5), Color(0xFFE91E8C), Color(0xFFFFD700), Color(0xFF2196F3),
    Color(0xFF4CAF50), Color(0xFFFF6B35), Color(0xFF9C27B0), Color(0xFF6B21FF),
  ];

  static List<Achievement> get _achievementDefs => [
        Achievement(id: 'first_session', emoji: '🎵', title: 'First Note', description: 'Log your first practice session'),
        Achievement(id: 'streak_7', emoji: '🔥', title: '7-Day Streak', description: 'Practice 7 days in a row'),
        Achievement(id: 'streak_30', emoji: '🔥', title: '30-Day Streak', description: 'Practice 30 days in a row'),
        Achievement(id: 'marathon', emoji: '⏱', title: 'Marathon', description: 'Log a 60+ minute session'),
        Achievement(id: 'hours_10', emoji: '🏆', title: '10 Hours', description: 'Reach 10 total hours practiced'),
        Achievement(id: 'hours_50', emoji: '🏆', title: '50 Hours', description: 'Reach 50 total hours practiced'),
        Achievement(id: 'hours_100', emoji: '🏆', title: '100 Hours', description: 'Reach 100 total hours practiced'),
        Achievement(id: 'repertoire_5', emoji: '🎼', title: 'Repertoire Builder', description: 'Add 5 pieces to your repertoire'),
        Achievement(id: 'goal_crusher', emoji: '🎯', title: 'Goal Crusher', description: 'Complete a practice goal on a piece'),
      ];

  Color _colorForInstrument(String instrument) {
    final index = _instruments.indexOf(instrument);
    return _instrumentColors[index % _instrumentColors.length];
  }

  Color _colorForPiece(String piece) {
    final pieces = _pieceMinutes.keys.toList();
    final index = pieces.indexOf(piece);
    return _pieceColors[index % _pieceColors.length];
  }

  String _formatDisplayDate(String rawDate) {
    const months = ['Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'Jun.', 'Jul.', 'Aug.', 'Sep.', 'Oct.', 'Nov.', 'Dec.'];
    try {
      final dt = DateTime.parse(rawDate.substring(0, 10));
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return rawDate; }
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('practiceSessions') ?? [];
    final sessions = data.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

    int total = 0;
    for (final s in sessions) total += (s['durationMinutes'] as int);

    final instrumentSet = <String>{};
    for (final s in sessions) {
      final inst = s['instrument'] as String? ?? '';
      if (inst.isNotEmpty) instrumentSet.add(inst);
    }
    final savedInstruments = prefs.getStringList('instruments') ?? [];
    instrumentSet.addAll(savedInstruments);

    final Map<String, int> pieceMap = {};
    for (final s in sessions) {
      final piece = s['piece'] as String? ?? '';
      final mins = s['durationMinutes'] as int? ?? 0;
      if (piece.isNotEmpty) pieceMap[piece] = (pieceMap[piece] ?? 0) + mins;
    }
    final sortedPieces = pieceMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sortedMap = Map<String, int>.fromEntries(sortedPieces);
    final totalPieceMins = sortedMap.values.fold(0, (a, b) => a + b);

    final songsData = prefs.getStringList('songs') ?? [];
    int goalsCompleted = 0;
    for (final s in songsData) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final goalMinutes = map['goalMinutes'] as int? ?? 0;
        if (goalMinutes > 0) {
          final title = map['title'] as String? ?? '';
          final practiced = pieceMap[title] ?? 0;
          if (practiced >= goalMinutes) goalsCompleted++;
        }
      } catch (_) {}
    }

    setState(() {
      _sessions = sessions;
      _totalSessions = sessions.length;
      _totalMinutes = total;
      _avgMinutes = sessions.isEmpty ? 0 : total / sessions.length;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
      _longestStreak = prefs.getInt('longestStreak') ?? 0;
      _userName = prefs.getString('userName') ?? 'Musician';
      _instruments = instrumentSet.toList();
      _pieceMinutes = sortedMap;
      _totalPieceMinutes = totalPieceMins;
      _pieceCount = songsData.length;
      _goalsCompleted = goalsCompleted;
    });

    await _loadAndCheckAchievements(prefs);
  }

  Future<void> _loadAndCheckAchievements(SharedPreferences prefs) async {
    final saved = prefs.getString('achievements');
    final Map<String, dynamic> savedMap = saved != null ? jsonDecode(saved) : {};
    final defs = _achievementDefs;
    final List<Achievement> achievements = defs.map((def) {
      if (savedMap.containsKey(def.id)) return Achievement.fromJson(def, savedMap[def.id]);
      return def;
    }).toList();

    final totalHours = _totalMinutes / 60;
    final now = DateTime.now().toString().substring(0, 10);
    bool changed = false;

    void unlock(Achievement a) {
      if (!a.unlocked) { a.unlocked = true; a.unlockedDate = now; changed = true; }
    }

    for (final a in achievements) {
      switch (a.id) {
        case 'first_session': if (_totalSessions >= 1) unlock(a); break;
        case 'streak_7': if (_longestStreak >= 7) unlock(a); break;
        case 'streak_30': if (_longestStreak >= 30) unlock(a); break;
        case 'marathon': if (_sessions.any((s) => (s['durationMinutes'] as int) >= 60)) unlock(a); break;
        case 'hours_10': if (totalHours >= 10) unlock(a); break;
        case 'hours_50': if (totalHours >= 50) unlock(a); break;
        case 'hours_100': if (totalHours >= 100) unlock(a); break;
        case 'repertoire_5': if (_pieceCount >= 5) unlock(a); break;
        case 'goal_crusher': if (_goalsCompleted >= 1) unlock(a); break;
      }
    }

    if (changed) {
      final toSave = {for (final a in achievements) a.id: a.toJson()};
      await prefs.setString('achievements', jsonEncode(toSave));
    }
    setState(() => _achievements = achievements);
  }

  // --- CSV Export ---
  Future<void> _exportCSV() async {
    if (_sessions.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Date,Duration (min),Instrument,Piece,Notes');

    final sortedSessions = List<Map<String, dynamic>>.from(_sessions)
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    for (final s in sortedSessions) {
      final date = (s['date'] as String).substring(0, 10);
      final mins = s['durationMinutes'] ?? 0;
      final inst = (s['instrument'] as String? ?? '').replaceAll(',', ' ');
      final piece = (s['piece'] as String? ?? '').replaceAll(',', ' ');
      final notes = (s['notes'] as String? ?? '').replaceAll(',', ' ').replaceAll('\n', ' ');
      buffer.writeln('$date,$mins,$inst,$piece,$notes');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/zyntune_practice_history.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Zyntune Practice History',
    );
  }

  List<Map<String, dynamic>> get _filteredSessions {
    if (_filterInstrument == 'All') return _sessions;
    return _sessions.where((s) => (s['instrument'] as String? ?? '') == _filterInstrument).toList();
  }

  int get _filteredMinutes {
    int total = 0;
    for (final s in _filteredSessions) total += (s['durationMinutes'] as int);
    return total;
  }

  Map<String, Map<String, dynamic>> get _instrumentStats {
    final Map<String, Map<String, dynamic>> stats = {};
    for (final inst in _instruments) {
      final instSessions = _sessions.where((s) => (s['instrument'] as String? ?? '') == inst).toList();
      int mins = 0;
      for (final s in instSessions) mins += (s['durationMinutes'] as int);
      stats[inst] = {'sessions': instSessions.length, 'minutes': mins, 'hours': mins / 60};
    }
    return stats;
  }

  Map<String, dynamic> get _bestDay {
    final Map<String, int> dayMap = {};
    for (final s in _filteredSessions) {
      final day = (s['date'] as String).substring(0, 10);
      dayMap[day] = (dayMap[day] ?? 0) + (s['durationMinutes'] as int);
    }
    if (dayMap.isEmpty) return {'date': '', 'minutes': 0};
    final best = dayMap.entries.reduce((a, b) => a.value > b.value ? a : b);
    return {'date': best.key, 'minutes': best.value};
  }

  Map<String, dynamic> get _bestWeek {
    if (_filteredSessions.isEmpty) return {'label': '', 'minutes': 0};
    final Map<String, int> weekMap = {};
    for (final s in _filteredSessions) {
      try {
        final date = DateTime.parse((s['date'] as String).substring(0, 10));
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final key = weekStart.toString().substring(0, 10);
        weekMap[key] = (weekMap[key] ?? 0) + (s['durationMinutes'] as int);
      } catch (_) {}
    }
    if (weekMap.isEmpty) return {'label': '', 'minutes': 0};
    final best = weekMap.entries.reduce((a, b) => a.value > b.value ? a : b);
    return {'label': _formatDisplayDate(best.key), 'minutes': best.value};
  }

  List<BarChartGroupData> _getWeeklyChartData() {
    final now = DateTime.now();
    final sessions = _filteredSessions;
    final List<BarChartGroupData> bars = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      int dayMinutes = 0;
      for (final s in sessions) {
        if ((s['date'] as String).substring(0, 10) == dayStr) dayMinutes += (s['durationMinutes'] as int);
      }
      bars.add(BarChartGroupData(x: 6 - i, barRods: [BarChartRodData(
        toY: dayMinutes.toDouble(),
        gradient: LinearGradient(colors: _filterInstrument == 'All' ? [const Color(0xFF6B21FF), const Color(0xFF9B59B6)] : [_colorForInstrument(_filterInstrument), _colorForInstrument(_filterInstrument).withOpacity(0.6)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
        width: 18, borderRadius: BorderRadius.circular(6),
      )]));
    }
    return bars;
  }

  List<BarChartGroupData> _getMonthlyChartData() {
    final now = DateTime.now();
    final sessions = _filteredSessions;
    final List<BarChartGroupData> bars = [];
    for (int i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: i * 7 + now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      int weekMinutes = 0;
      for (final s in sessions) {
        try {
          final sessionDate = DateTime.parse((s['date'] as String).substring(0, 10));
          if (sessionDate.isAfter(weekStart.subtract(const Duration(days: 1))) && sessionDate.isBefore(weekEnd.add(const Duration(days: 1)))) {
            weekMinutes += (s['durationMinutes'] as int);
          }
        } catch (e) {}
      }
      bars.add(BarChartGroupData(x: 7 - i, barRods: [BarChartRodData(
        toY: weekMinutes.toDouble(),
        gradient: LinearGradient(colors: _filterInstrument == 'All' ? [const Color(0xFF9C27B0), const Color(0xFFE91E8C)] : [_colorForInstrument(_filterInstrument), _colorForInstrument(_filterInstrument).withOpacity(0.6)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
        width: 18, borderRadius: BorderRadius.circular(6),
      )]));
    }
    return bars;
  }

  List<BarChartGroupData> _getSixMonthChartData() {
    final now = DateTime.now();
    final sessions = _filteredSessions;
    final List<BarChartGroupData> bars = [];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      int monthMinutes = 0;
      for (final s in sessions) {
        try {
          final d = DateTime.parse((s['date'] as String).substring(0, 10));
          if (d.year == month.year && d.month == month.month) monthMinutes += (s['durationMinutes'] as int);
        } catch (_) {}
      }
      bars.add(BarChartGroupData(x: 5 - i, barRods: [BarChartRodData(
        toY: monthMinutes.toDouble(),
        gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF00897B)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
        width: 22, borderRadius: BorderRadius.circular(6),
      )]));
    }
    return bars;
  }

  String _getWeeklyLabel(int index) {
    final now = DateTime.now();
    final day = now.subtract(Duration(days: 6 - index));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day.weekday - 1];
  }

  String _getMonthlyLabel(int index) => 'W${index + 1}';

  String _getSixMonthLabel(int index) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - (5 - index), 1);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month.month - 1];
  }

  String _generateShareText() {
    final hours = (_totalMinutes / 60).toStringAsFixed(1);
    final instLines = _instrumentStats.entries.map((e) => '  ${e.key}: ${e.value['sessions']} sessions, ${e.value['minutes']} min').join('\n');
    final unlockedBadges = _achievements.where((a) => a.unlocked).map((a) => '  ${a.emoji} ${a.title}').join('\n');
    return '''My Zyntune Stats 🎵

Musician: $_userName

Total Sessions: $_totalSessions
Total Minutes: $_totalMinutes
Total Hours: $hours
Avg per Session: ${_avgMinutes.round()} min

Current Streak: $_currentStreak days
Best Streak: $_longestStreak days

By Instrument:
$instLines

${unlockedBadges.isNotEmpty ? 'Achievements:\n$unlockedBadges\n' : ''}
Keep practicing! 🎸''';
  }

  void _shareStats() {
    Clipboard.setData(ClipboardData(text: _generateShareText()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stats copied to clipboard!'), backgroundColor: Colors.green, duration: Duration(seconds: 3)));
  }

  Widget _buildAchievements() {
    if (_achievements.isEmpty) return const SizedBox.shrink();
    final unlocked = _achievements.where((a) => a.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Achievements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('$unlocked / ${_achievements.length}', style: const TextStyle(fontSize: 13, color: Color(0xFF9B59B6), fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
          itemCount: _achievements.length,
          itemBuilder: (context, index) {
            final a = _achievements[index];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: a.unlocked ? LinearGradient(colors: [_purple.withOpacity(0.3), const Color(0xFF9B59B6).withOpacity(0.2)]) : null,
                color: a.unlocked ? null : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: a.unlocked ? _purple.withOpacity(0.5) : Colors.white.withOpacity(0.08)),
                boxShadow: a.unlocked ? [BoxShadow(color: _purple.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(a.emoji, style: TextStyle(fontSize: 28, color: a.unlocked ? null : Colors.white)),
                const SizedBox(height: 6),
                Text(a.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: a.unlocked ? Colors.white : Colors.white30)),
                const SizedBox(height: 3),
                Text(a.unlocked && a.unlockedDate != null ? _formatDisplayDate(a.unlockedDate!) : a.description, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: a.unlocked ? const Color(0xFF9B59B6) : Colors.white12)),
              ]),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPieceBreakdown() {
    if (_pieceMinutes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Time by Piece', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        ..._pieceMinutes.entries.map((entry) {
          final piece = entry.key;
          final mins = entry.value;
          final color = _colorForPiece(piece);
          final pct = _totalPieceMinutes == 0 ? 0.0 : mins / _totalPieceMinutes;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.12), color.withOpacity(0.06)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.music_note, color: color, size: 16)),
                const SizedBox(width: 10),
                Expanded(child: Text(piece, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                Text('${(pct * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white.withOpacity(0.1), color: color, minHeight: 6)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_formatMinutes(mins), style: TextStyle(color: color.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${(mins / 60).toStringAsFixed(1)} hrs total', style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
              ]),
            ]),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAdvancedStats(bool isPro) {
    if (isPro) {
      final bestDay = _bestDay;
      final bestWeek = _bestWeek;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Advanced Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]), borderRadius: BorderRadius.circular(10)), child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(label: 'Best Day', value: bestDay['minutes'] > 0 ? _formatMinutes(bestDay['minutes']) : '—', icon: Icons.today, color: const Color(0xFF00BFA5))),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Best Week', value: bestWeek['minutes'] > 0 ? _formatMinutes(bestWeek['minutes']) : '—', icon: Icons.calendar_view_week, color: const Color(0xFF9C27B0))),
        ]),
        const SizedBox(height: 24),
      ]);
    } else {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [_purple.withOpacity(0.15), const Color(0xFF9B59B6).withOpacity(0.08)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.3))),
          child: Column(children: [
            const Text('⭐', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text('Advanced Stats', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Unlock Best Day, Best Week, 6-month chart history and more with Zyntune Pro', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4)),
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]), borderRadius: BorderRadius.circular(20)), child: const Text('Unlock with Pro', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
          ]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = PurchaseService().isPro;
    final isWeekly = _viewMode == 'weekly';
    final isSixMonth = _viewMode == 'sixmonth';
    List<BarChartGroupData> chartData;
    if (isSixMonth) { chartData = _getSixMonthChartData(); }
    else if (isWeekly) { chartData = _getWeeklyChartData(); }
    else { chartData = _getMonthlyChartData(); }

    final instStats = _instrumentStats;
    final displayMinutes = _filterInstrument == 'All' ? _totalMinutes : _filteredMinutes;
    final displaySessions = _filteredSessions.length;
    final displayAvg = displaySessions == 0 ? 0.0 : displayMinutes / displaySessions;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Stats', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [_purple, Color(0xFF9B59B6)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        actions: [
          if (_totalSessions > 0)
            IconButton(
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              tooltip: 'Export CSV',
              onPressed: _exportCSV,
            ),
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _totalSessions > 0 ? _shareStats : null),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (_instruments.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _FilterChip(label: 'All', isSelected: _filterInstrument == 'All', color: _purple, onTap: () => setState(() => _filterInstrument = 'All')),
                  const SizedBox(width: 8),
                  ..._instruments.map((inst) => Padding(padding: const EdgeInsets.only(right: 8), child: _FilterChip(label: inst, isSelected: _filterInstrument == inst, color: _colorForInstrument(inst), onTap: () => setState(() => _filterInstrument = inst)))),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            Row(children: [
              Expanded(child: _StatCard(label: 'Total Sessions', value: '$displaySessions', icon: Icons.event_note_outlined, color: const Color(0xFF2196F3))),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Total Minutes', value: '$displayMinutes', icon: Icons.timer_outlined, color: const Color(0xFF00BFA5))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(label: 'Avg / Session', value: '${displayAvg.round()} min', icon: Icons.trending_up, color: _purple)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Total Hours', value: '${(displayMinutes / 60).toStringAsFixed(1)}h', icon: Icons.star_outline, color: const Color(0xFFFF6B35))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _StatCard(label: 'Current Streak', value: '$_currentStreak days', icon: Icons.local_fire_department, color: const Color(0xFFFF4444), emoji: '🔥')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Best Streak', value: '$_longestStreak days', icon: Icons.emoji_events, color: const Color(0xFFFFD700), emoji: '🏆')),
            ]),
            const SizedBox(height: 24),

            _buildAchievements(),
            _buildAdvancedStats(isPro),

            if (_instruments.length > 1 && _filterInstrument == 'All') ...[
              const Text('By Instrument', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              ...instStats.entries.map((entry) {
                final inst = entry.key;
                final stats = entry.value;
                final color = _colorForInstrument(inst);
                final pct = _totalMinutes == 0 ? 0.0 : (stats['minutes'] as int) / _totalMinutes;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.12), color.withOpacity(0.06)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.music_note, color: color, size: 16)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(inst, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15))),
                      Text('${(pct * 100).round()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, backgroundColor: Colors.white.withOpacity(0.1), color: color, minHeight: 6)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${stats['sessions']} sessions', style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
                      Text('${stats['minutes']} min  •  ${(stats['hours'] as double).toStringAsFixed(1)}h', style: TextStyle(color: color.withOpacity(0.7), fontSize: 12)),
                    ]),
                  ]),
                );
              }),
              const SizedBox(height: 12),
            ],

            _buildPieceBreakdown(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isSixMonth ? 'Last 6 Months' : isWeekly ? 'Last 7 Days' : 'Last 8 Weeks', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Container(
                  decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.3))),
                  child: Row(children: [
                    GestureDetector(onTap: () => setState(() => _viewMode = 'weekly'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(gradient: isWeekly ? const LinearGradient(colors: [_purple, Color(0xFF9B59B6)]) : null, borderRadius: BorderRadius.circular(20)), child: Text('Week', style: TextStyle(color: isWeekly ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)))),
                    GestureDetector(onTap: () => setState(() => _viewMode = 'monthly'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(gradient: (!isWeekly && !isSixMonth) ? const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE91E8C)]) : null, borderRadius: BorderRadius.circular(20)), child: Text('8 Weeks', style: TextStyle(color: (!isWeekly && !isSixMonth) ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)))),
                    if (isPro)
                      GestureDetector(onTap: () => setState(() => _viewMode = 'sixmonth'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(gradient: isSixMonth ? const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF00897B)]) : null, borderRadius: BorderRadius.circular(20)), child: Row(children: [Text('6 Mo', style: TextStyle(color: isSixMonth ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(width: 3), const Text('⭐', style: TextStyle(fontSize: 9))]))),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity, height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: _purple.withOpacity(0.3)), boxShadow: [BoxShadow(color: _purple.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))]),
              child: _sessions.isEmpty
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.bar_chart, color: Colors.white24, size: 48), SizedBox(height: 12), Text('No practice data yet!\nStart a session to see your stats', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 13))])
                  : BarChart(BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: chartData.isEmpty ? 10 : (chartData.map((g) => g.barRods.first.toY).reduce((a, b) => a > b ? a : b) * 1.3).ceilToDouble(),
                      barGroups: chartData,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (val, meta) => Text('${val.round()}', style: const TextStyle(fontSize: 10, color: Colors.white38)))),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => Text(isSixMonth ? _getSixMonthLabel(val.round()) : isWeekly ? _getWeeklyLabel(val.round()) : _getMonthlyLabel(val.round()), style: const TextStyle(fontSize: 10, color: Colors.white54)))),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                    )),
            ),
            const SizedBox(height: 24),

            if (_totalSessions > 0) ...[
              const Text('Share Your Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_generateShareText(), style: const TextStyle(fontSize: 13, color: Colors.white70, fontFamily: 'monospace', height: 1.5)),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _shareStats,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy to Clipboard'),
                    style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  )),
                ]),
              ),
              const SizedBox(height: 24),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Practice History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                if (_totalSessions > 0)
                  GestureDetector(
                    onTap: _exportCSV,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF00BFA5).withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.4))),
                      child: const Row(children: [
                        Icon(Icons.download_outlined, size: 14, color: Color(0xFF00BFA5)),
                        SizedBox(width: 4),
                        Text('Export CSV', style: TextStyle(fontSize: 12, color: Color(0xFF00BFA5), fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            _filteredSessions.isEmpty
                ? Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2]), borderRadius: BorderRadius.circular(20), border: Border.all(color: _purple.withOpacity(0.3))), child: const Column(children: [Icon(Icons.history, color: Colors.white24, size: 36), SizedBox(height: 8), Text('No sessions recorded yet.', style: TextStyle(color: Colors.white38, fontSize: 14))]))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredSessions.length,
                    itemBuilder: (context, index) {
                      final session = _filteredSessions[_filteredSessions.length - 1 - index];
                      final inst = session['instrument'] as String? ?? '';
                      final color = inst.isNotEmpty && _instruments.contains(inst) ? _colorForInstrument(inst) : _purple;
                      final displayDate = _formatDisplayDate(session['date'] as String);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), border: Border.all(color: _purple.withOpacity(0.25))),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(Icons.music_note, color: color, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text('${session['durationMinutes']} minutes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              if (inst.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text(inst, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
                              ],
                            ]),
                            Text(session['notes'] != null && session['notes'].isNotEmpty ? '$displayDate • ${session['notes']}' : displayDate, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ])),
                        ]),
                      );
                    }),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? color : color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4)), boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : []),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? emoji;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.emoji});

  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_cardBg, _cardBg2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(0.4)), boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: emoji != null ? Text(emoji!, style: const TextStyle(fontSize: 16)) : Icon(icon, color: color, size: 18)),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7), fontWeight: FontWeight.w500)),
      ]),
    );
  }
}