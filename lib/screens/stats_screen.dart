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
  String _viewMode = 'weekly'; // 'weekly' or 'monthly'

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('practiceSessions') ?? [];
    final sessions = data
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();

    int total = 0;
    for (final s in sessions) {
      total += (s['durationMinutes'] as int);
    }

    setState(() {
      _sessions = sessions;
      _totalSessions = sessions.length;
      _totalMinutes = total;
      _avgMinutes =
          sessions.isEmpty ? 0 : total / sessions.length;
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
      _longestStreak = prefs.getInt('longestStreak') ?? 0;
      _userName = prefs.getString('userName') ?? 'Musician';
      _instrument =
          prefs.getString('instrument') ?? 'Guitar';
    });
  }

  // Get last 7 days chart data
  List<BarChartGroupData> _getWeeklyChartData() {
    final now = DateTime.now();
    final List<BarChartGroupData> bars = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      int dayMinutes = 0;
      for (final s in _sessions) {
        final sessionDate =
            (s['date'] as String).substring(0, 10);
        if (sessionDate == dayStr) {
          dayMinutes += (s['durationMinutes'] as int);
        }
      }

      bars.add(BarChartGroupData(
        x: 6 - i,
        barRods: [
          BarChartRodData(
            toY: dayMinutes.toDouble(),
            color: Colors.blue,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ));
    }
    return bars;
  }

  // Get last 8 weeks chart data
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
          final sessionDate = DateTime.parse(
              (s['date'] as String).substring(0, 10));
          if (sessionDate
                  .isAfter(weekStart.subtract(const Duration(days: 1))) &&
              sessionDate
                  .isBefore(weekEnd.add(const Duration(days: 1)))) {
            weekMinutes += (s['durationMinutes'] as int);
          }
        } catch (e) {
          // Skip
        }
      }

      bars.add(BarChartGroupData(
        x: 7 - i,
        barRods: [
          BarChartRodData(
            toY: weekMinutes.toDouble(),
            color: Colors.purple,
            width: 20,
            borderRadius: BorderRadius.circular(4),
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

  String _getMonthlyLabel(int index) {
    final now = DateTime.now();
    final weekStart = now.subtract(
        Duration(days: (7 - index) * 7 + now.weekday - 1));
    return 'W${index + 1}';
  }

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
    final text = _generateShareText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Stats copied to clipboard! Paste anywhere to share.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWeekly = _viewMode == 'weekly';
    final chartData = isWeekly
        ? _getWeeklyChartData()
        : _getMonthlyChartData();
    final chartColor = isWeekly ? Colors.blue : Colors.purple;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _totalSessions > 0 ? _shareStats : null,
            tooltip: 'Share Stats',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Summary Cards ---
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Sessions',
                    value: '$_totalSessions',
                    icon: Icons.event_note,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Minutes',
                    value: '$_totalMinutes',
                    icon: Icons.timer,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Avg per Session',
                    value: '${_avgMinutes.round()} min',
                    icon: Icons.trending_up,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Total Hours',
                    value:
                        '${(_totalMinutes / 60).toStringAsFixed(1)}h',
                    icon: Icons.star,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Current Streak',
                    value: '$_currentStreak days',
                    icon: Icons.local_fire_department,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Best Streak',
                    value: '$_longestStreak days',
                    icon: Icons.emoji_events,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Chart Toggle ---
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isWeekly ? 'Last 7 Days' : 'Last 8 Weeks',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(
                            () => _viewMode = 'weekly'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isWeekly
                                ? Colors.blue
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Week',
                            style: TextStyle(
                              color: isWeekly
                                  ? Colors.white
                                  : colorScheme.onSurface
                                      .withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(
                            () => _viewMode = 'monthly'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: !isWeekly
                                ? Colors.purple
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Monthly',
                            style: TextStyle(
                              color: !isWeekly
                                  ? Colors.white
                                  : colorScheme.onSurface
                                      .withOpacity(0.6),
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
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: chartColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: chartColor.withOpacity(0.2),
                    width: 1.5),
              ),
              child: _sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No practice data yet!\nStart a session to see your stats',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment:
                            BarChartAlignment.spaceAround,
                        maxY: chartData.isEmpty
                            ? 10
                            : (chartData
                                        .map((g) =>
                                            g.barRods.first.toY)
                                        .reduce((a, b) =>
                                            a > b ? a : b) *
                                    1.3)
                                .ceilToDouble(),
                        barGroups: chartData,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (val, meta) =>
                                  Text('${val.round()}',
                                      style: const TextStyle(
                                          fontSize: 10)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) =>
                                  Text(
                                isWeekly
                                    ? _getWeeklyLabel(
                                        val.round())
                                    : _getMonthlyLabel(
                                        val.round()),
                                style: const TextStyle(
                                    fontSize: 10),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) =>
                              FlLine(
                            color: chartColor.withOpacity(0.1),
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
              Text('Share Your Progress',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  )),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          Colors.deepPurple.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _generateShareText(),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface
                            .withOpacity(0.8),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _shareStats,
                        icon: const Icon(Icons.copy),
                        label:
                            const Text('Copy to Clipboard'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- Practice History ---
            Text('Practice History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                )),
            const SizedBox(height: 12),

            _sessions.isEmpty
                ? Text(
                    'No sessions recorded yet.',
                    style: TextStyle(
                      color: colorScheme.onSurface
                          .withOpacity(0.5),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[
                          _sessions.length - 1 - index];
                      return Card(
                        margin:
                            const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.music_note,
                                color: Colors.white,
                                size: 18),
                          ),
                          title: Text(
                              '${session['durationMinutes']} minutes'),
                          subtitle: Text(
                            session['notes'] != null &&
                                    session['notes'].isNotEmpty
                                ? '${session['date']} • ${session['notes']}'
                                : '${session['date']}',
                          ),
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}