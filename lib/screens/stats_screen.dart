import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

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
  String _instrument = 'Guitar';
  String _viewMode = 'weekly';

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('practiceSessions') ?? [];
    final sessions =
        data.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

    int total = 0;
    for (final s in sessions) {
      total += (s['durationMinutes'] as int);
    }

    setState(() {
      _sessions = sessions;
      _totalSessions = sessions.length;
      _totalMinutes = total;
      _avgMinutes = sessions.isEmpty ? 0 : total / sessions.length;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
      _longestStreak = prefs.getInt('longestStreak') ?? 0;
      _userName = prefs.getString('userName') ?? 'Musician';
      _instrument = prefs.getString('instrument') ?? 'Guitar';
    });
  }

  List<BarChartGroupData> _getWeeklyChartData() {
    final now = DateTime.now();
    final List<BarChartGroupData> bars = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      int dayMinutes = 0;
      for (final s in _sessions) {
        final sessionDate = (s['date'] as String).substring(0, 10);
        if (sessionDate == dayStr) {
          dayMinutes += (s['durationMinutes'] as int);
        }
      }
      bars.add(BarChartGroupData(
        x: 6 - i,
        barRods: [
          BarChartRodData(
            toY: dayMinutes.toDouble(),
            gradient: const LinearGradient(
              colors: [Color(0xFF6B21FF), Color(0xFF9B59B6)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ));
    }
    return bars;
  }

  List<BarChartGroupData> _getMonthlyChartData() {
    final now = DateTime.now();
    final List<BarChartGroupData> bars = [];
    for (int i = 7; i >= 0; i--) {
      final weekStart =
          now.subtract(Duration(days: i * 7 + now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      int weekMinutes = 0;
      for (final s in _sessions) {
        try {
          final sessionDate =
              DateTime.parse((s['date'] as String).substring(0, 10));
          if (sessionDate.isAfter(
                  weekStart.subtract(const Duration(days: 1))) &&
              sessionDate
                  .isBefore(weekEnd.add(const Duration(days: 1)))) {
            weekMinutes += (s['durationMinutes'] as int);
          }
        } catch (e) {}
      }
      bars.add(BarChartGroupData(
        x: 7 - i,
        barRods: [
          BarChartRodData(
            toY: weekMinutes.toDouble(),
            gradient: const LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFFE91E8C)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ));
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

  String _generateShareText() {
    final hours = (_totalMinutes / 60).toStringAsFixed(1);
    return '''My Zyntune Stats 🎵

Musician: $_userName
Instrument: $_instrument

Total Sessions: $_totalSessions
Total Minutes: $_totalMinutes
Total Hours: $hours
Avg per Session: ${_avgMinutes.round()} min

Current Streak: $_currentStreak days
Best Streak: $_longestStreak days

Keep practicing! 🎸''';
  }

  void _shareStats() {
    Clipboard.setData(ClipboardData(text: _generateShareText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stats copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeekly = _viewMode == 'weekly';
    final chartData =
        isWeekly ? _getWeeklyChartData() : _getMonthlyChartData();

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Stats',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _totalSessions > 0 ? _shareStats : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Summary Cards ---
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Sessions',
                    value: '$_totalSessions',
                    icon: Icons.event_note_outlined,
                    color: const Color(0xFF2196F3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Total Minutes',
                    value: '$_totalMinutes',
                    icon: Icons.timer_outlined,
                    color: const Color(0xFF00BFA5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Avg / Session',
                    value: '${_avgMinutes.round()} min',
                    icon: Icons.trending_up,
                    color: _purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Total Hours',
                    value: '${(_totalMinutes / 60).toStringAsFixed(1)}h',
                    icon: Icons.star_outline,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Current Streak',
                    value: '$_currentStreak days',
                    icon: Icons.local_fire_department,
                    color: const Color(0xFFFF4444),
                    emoji: '🔥',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Best Streak',
                    value: '$_longestStreak days',
                    icon: Icons.emoji_events,
                    color: const Color(0xFFFFD700),
                    emoji: '🏆',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Chart Toggle ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isWeekly ? 'Last 7 Days' : 'Last 8 Weeks',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _purple.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _viewMode = 'weekly'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isWeekly
                                ? const LinearGradient(colors: [
                                    _purple,
                                    Color(0xFF9B59B6)
                                  ])
                                : null,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Week',
                            style: TextStyle(
                              color: isWeekly
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _viewMode = 'monthly'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: !isWeekly
                                ? const LinearGradient(colors: [
                                    Color(0xFF9C27B0),
                                    Color(0xFFE91E8C)
                                  ])
                                : null,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Monthly',
                            style: TextStyle(
                              color: !isWeekly
                                  ? Colors.white
                                  : Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Bar Chart ---
            Container(
              width: double.infinity,
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_cardBg, _cardBg2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _purple.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _sessions.isEmpty
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart,
                            color: Colors.white24, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No practice data yet!\nStart a session to see your stats',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: chartData.isEmpty
                            ? 10
                            : (chartData
                                        .map((g) => g.barRods.first.toY)
                                        .reduce((a, b) => a > b ? a : b) *
                                    1.3)
                                .ceilToDouble(),
                        barGroups: chartData,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (val, meta) => Text(
                                '${val.round()}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white38),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) => Text(
                                isWeekly
                                    ? _getWeeklyLabel(val.round())
                                    : _getMonthlyLabel(val.round()),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white54),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: Colors.white.withOpacity(0.05),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // --- Share Card ---
            if (_totalSessions > 0) ...[
              const Text('Share Your Progress',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_cardBg, _cardBg2],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _purple.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _generateShareText(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareStats,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy to Clipboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- Practice History ---
            const Text('Practice History',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 12),

            _sessions.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_cardBg, _cardBg2]),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _purple.withOpacity(0.3)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.history,
                            color: Colors.white24, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'No sessions recorded yet.',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session =
                          _sessions[_sessions.length - 1 - index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_cardBg, _cardBg2],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _purple.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _purple.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.music_note,
                                  color: Color(0xFF9B59B6),
                                  size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${session['durationMinutes']} minutes',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    session['notes'] != null &&
                                            session['notes'].isNotEmpty
                                        ? '${session['date']} • ${session['notes']}'
                                        : '${session['date']}',
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
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

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.emoji,
  });

  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_cardBg, _cardBg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: emoji != null
                ? Text(emoji!, style: const TextStyle(fontSize: 16))
                : Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}