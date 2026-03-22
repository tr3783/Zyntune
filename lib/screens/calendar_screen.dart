import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  Map<String, int> _practiceData = {}; // date -> minutes
  int _selectedDayMinutes = 0;
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    _loadPracticeData();
  }

  Future<void> _loadPracticeData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('practiceSessions') ?? [];
    final Map<String, int> practiceMap = {};

    for (final s in data) {
      try {
        final session = jsonDecode(s) as Map<String, dynamic>;
        final date = (session['date'] as String).substring(0, 10);
        final mins = session['durationMinutes'] as int;
        practiceMap[date] = (practiceMap[date] ?? 0) + mins;
      } catch (e) {
        // Skip invalid sessions
      }
    }

    setState(() => _practiceData = practiceMap);
  }

  // Get all days in the focused month
  List<DateTime?> _getDaysInMonth() {
    final firstDay =
        DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

    final days = <DateTime?>[];

    // Add empty slots for days before the first day
    for (int i = 1; i < firstDay.weekday; i++) {
      days.add(null);
    }

    // Add all days in the month
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(
          DateTime(_focusedMonth.year, _focusedMonth.month, i));
    }

    return days;
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  // Get color intensity based on practice minutes
  Color _getDayColor(int minutes) {
    if (minutes == 0) return Colors.transparent;
    if (minutes < 15) return Colors.deepPurple.withOpacity(0.3);
    if (minutes < 30) return Colors.deepPurple.withOpacity(0.5);
    if (minutes < 60) return Colors.deepPurple.withOpacity(0.75);
    return Colors.deepPurple;
  }

  // Get total practice days in month
  int get _practiceDaysThisMonth {
    return _practiceData.keys.where((date) {
      return date.startsWith(
          '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}');
    }).length;
  }

  // Get total minutes this month
  int get _totalMinutesThisMonth {
    int total = 0;
    for (final entry in _practiceData.entries) {
      if (entry.key.startsWith(
          '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}')) {
        total += entry.value;
      }
    }
    return total;
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(
          _focusedMonth.year, _focusedMonth.month - 1);
      _selectedDate = '';
      _selectedDayMinutes = 0;
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(
          _focusedMonth.year, _focusedMonth.month + 1);
      _selectedDate = '';
      _selectedDayMinutes = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = _getDaysInMonth();
    final today = DateTime.now();
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const months = [
      'January', 'February', 'March', 'April', 'May',
      'June', 'July', 'August', 'September', 'October',
      'November', 'December'
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Calendar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          children: [

            // --- Month Summary ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade700,
                    Colors.purple.shade800
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [
                  _MonthStat(
                    label: 'Days Practiced',
                    value: '$_practiceDaysThisMonth',
                    icon: Icons.calendar_today,
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white24),
                  _MonthStat(
                    label: 'Total Minutes',
                    value: '$_totalMinutesThisMonth',
                    icon: Icons.timer,
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white24),
                  _MonthStat(
                    label: 'Total Hours',
                    value:
                        '${(_totalMinutesThisMonth / 60).toStringAsFixed(1)}',
                    icon: Icons.star,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- Month Navigation ---
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // --- Weekday Headers ---
            Row(
              children: weekdays
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),

            // --- Calendar Grid ---
            GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                if (day == null) {
                  return const SizedBox();
                }

                final key = _dateKey(day);
                final minutes = _practiceData[key] ?? 0;
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final isSelected = key == _selectedDate;
                final isFuture = day.isAfter(today);
                final hasPractice = minutes > 0;

                return GestureDetector(
                  onTap: isFuture
                      ? null
                      : () {
                          setState(() {
                            _selectedDate = key;
                            _selectedDayMinutes = minutes;
                          });
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.deepPurple
                          : hasPractice
                              ? _getDayColor(minutes)
                              : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(
                              color: Colors.deepPurple,
                              width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : isFuture
                                    ? colorScheme.onSurface
                                        .withOpacity(0.3)
                                    : hasPractice
                                        ? Colors.white
                                        : colorScheme
                                            .onSurface,
                          ),
                        ),
                        if (hasPractice && !isSelected)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // --- Selected Day Info ---
            if (_selectedDate.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          Colors.deepPurple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event,
                        color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            _selectedDayMinutes == 0
                                ? 'No practice recorded'
                                : '$_selectedDayMinutes minutes practiced',
                            style: TextStyle(
                              color: colorScheme.onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedDayMinutes > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_selectedDayMinutes min',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // --- Legend ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Less  ',
                    style: TextStyle(fontSize: 12)),
                ...[ 0.3, 0.5, 0.75, 1.0].map((opacity) =>
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple
                          .withOpacity(opacity),
                      borderRadius:
                          BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text('  More',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MonthStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}