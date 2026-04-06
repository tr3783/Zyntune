import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum EventType { recital, audition, lesson, deadline, performance, other }

class CalendarEvent {
  final String id;
  String title;
  EventType type;
  String date;
  String notes;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'date': date,
        'notes': notes,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) =>
      CalendarEvent(
        id: json['id'],
        title: json['title'],
        type: EventType.values.firstWhere(
            (t) => t.name == (json['type'] ?? 'other'),
            orElse: () => EventType.other),
        date: json['date'],
        notes: json['notes'] ?? '',
      );
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() =>
      _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  Map<String, int> _practiceData = {};
  Map<String, List<CalendarEvent>> _events = {};
  int _selectedDayMinutes = 0;
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load practice sessions
    final data = prefs.getStringList('practiceSessions') ?? [];
    final Map<String, int> practiceMap = {};
    for (final s in data) {
      try {
        final session =
            jsonDecode(s) as Map<String, dynamic>;
        final date =
            (session['date'] as String).substring(0, 10);
        final mins = session['durationMinutes'] as int;
        practiceMap[date] =
            (practiceMap[date] ?? 0) + mins;
      } catch (e) {}
    }

    // Load events
    final eventData =
        prefs.getStringList('calendarEvents') ?? [];
    final Map<String, List<CalendarEvent>> eventsMap = {};
    for (final s in eventData) {
      try {
        final event = CalendarEvent.fromJson(jsonDecode(s));
        eventsMap[event.date] ??= [];
        eventsMap[event.date]!.add(event);
      } catch (e) {}
    }


    // Load goals due dates
    final goalsList =
        prefs.getStringList('longTermGoals') ?? [];
    for (final s in goalsList) {
      try {
        final g = jsonDecode(s) as Map<String, dynamic>;
        final dueDate = g['dueDate'] as String? ?? '';
        if (dueDate.isEmpty) continue;
        final isCompleted = g['isCompleted'] as bool? ?? false;
        if (isCompleted) continue;
        final goalEvent = CalendarEvent(
          id: 'goal_${g['id']}',
          title: g['title'] ?? '',
          type: EventType.deadline,
          date: dueDate,
          notes: '${(g['category'] ?? 'weekly').toString().toUpperCase()} GOAL',
        );
        eventsMap[dueDate] ??= [];
        // Avoid duplicates
        if (!eventsMap[dueDate]!
            .any((e) => e.id == goalEvent.id)) {
          eventsMap[dueDate]!.add(goalEvent);
        }
      } catch (e) {}
    }

    setState(() {
      _practiceData = practiceMap;
      _events = eventsMap;
    });
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final allEvents =
        _events.values.expand((e) => e).toList();
    await prefs.setStringList('calendarEvents',
        allEvents.map((e) => jsonEncode(e.toJson())).toList());
  }

  List<DateTime?> _getDaysInMonth() {
    final firstDay = DateTime(
        _focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(
        _focusedMonth.year, _focusedMonth.month + 1, 0);
    final days = <DateTime?>[];
    for (int i = 1; i < firstDay.weekday; i++) {
      days.add(null);
    }
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(
          _focusedMonth.year, _focusedMonth.month, i));
    }
    return days;
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Color _getDayColor(int minutes) {
    if (minutes == 0) return Colors.transparent;
    if (minutes < 15)
      return Colors.deepPurple.withOpacity(0.3);
    if (minutes < 30)
      return Colors.deepPurple.withOpacity(0.5);
    if (minutes < 60)
      return Colors.deepPurple.withOpacity(0.75);
    return Colors.deepPurple;
  }

  Color _eventTypeColor(EventType type) {
    switch (type) {
      case EventType.recital:
        return Colors.pink;
      case EventType.audition:
        return Colors.red;
      case EventType.lesson:
        return Colors.blue;
      case EventType.deadline:
        return Colors.orange;
      case EventType.performance:
        return Colors.green;
      case EventType.other:
        return Colors.grey;
    }
  }

  IconData _eventTypeIcon(EventType type) {
    switch (type) {
      case EventType.recital:
        return Icons.piano;
      case EventType.audition:
        return Icons.record_voice_over;
      case EventType.lesson:
        return Icons.school;
      case EventType.deadline:
        return Icons.flag;
      case EventType.performance:
        return Icons.theater_comedy;
      case EventType.other:
        return Icons.event;
    }
  }

  String _eventTypeLabel(EventType type) =>
      type.name[0].toUpperCase() + type.name.substring(1);

  int get _practiceDaysThisMonth {
    return _practiceData.keys.where((date) {
      return date.startsWith(
          '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}');
    }).length;
  }

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

  void _showAddEventDialog(String date) {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    EventType selectedType = EventType.lesson;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Event — $date'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title *',
                    hintText: 'e.g. Spring Recital',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Event Type',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EventType.values.map((type) {
                    final isSelected =
                        selectedType == type;
                    final color = _eventTypeColor(type);
                    return GestureDetector(
                      onTap: () => setDialogState(
                          () => selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color
                              : color.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  color.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                _eventTypeIcon(type),
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : color),
                            const SizedBox(width: 4),
                            Text(
                              _eventTypeLabel(type),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : color,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Wear formal attire',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
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
                if (titleController.text.trim().isEmpty)
                  return;
                final event = CalendarEvent(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  title: titleController.text.trim(),
                  type: selectedType,
                  date: date,
                  notes: notesController.text.trim(),
                );
                setState(() {
                  _events[date] ??= [];
                  _events[date]!.add(event);
                });
                _saveEvents();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Event'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEvent(CalendarEvent event) {
    setState(() {
      _events[event.date]?.remove(event);
      if (_events[event.date]?.isEmpty ?? false) {
        _events.remove(event.date);
      }
    });
    _saveEvents();
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

    final selectedEvents = _events[_selectedDate] ?? [];
    final selectedMinutes = _practiceData[_selectedDate] ?? 0;

    // Upcoming events this month
    final todayStr = _dateKey(today);
    final upcomingEvents = _events.entries
        .where((e) =>
            e.key.startsWith(
                '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}') &&
            e.key.compareTo(todayStr) >= 0)
        .expand((e) => e.value)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Calendar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 48),
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
                    value: (_totalMinutesThisMonth / 60)
                        .toStringAsFixed(1),
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
                childAspectRatio: 0.85,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                if (day == null) return const SizedBox();

                final key = _dateKey(day);
                final minutes =
                    _practiceData[key] ?? 0;
                final dayEvents = _events[key] ?? [];
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final isSelected = key == _selectedDate;
                final hasPractice = minutes > 0;
                final hasEvents = dayEvents.isNotEmpty;

                return GestureDetector(
                  onTap: () {
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
                            fontSize: 13,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : hasPractice
                                    ? Colors.white
                                    : colorScheme
                                        .onSurface,
                          ),
                        ),
                        if (hasEvents)
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: dayEvents
                                .take(3)
                                .map((e) => Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets
                                          .symmetric(
                                          horizontal: 1),
                                      decoration:
                                          BoxDecoration(
                                        color:
                                            _eventTypeColor(
                                                e.type),
                                        shape:
                                            BoxShape.circle,
                                      ),
                                    ))
                                .toList(),
                          )
                        else if (hasPractice &&
                            !isSelected)
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
            const SizedBox(height: 16),

            // --- Selected Day Info ---
            if (_selectedDate.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.deepPurple
                          .withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              _showAddEventDialog(
                                  _selectedDate),
                          icon: const Icon(Icons.add,
                              size: 16),
                          label: const Text('Add Event'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      selectedMinutes == 0
                          ? 'No practice recorded'
                          : '$selectedMinutes minutes practiced',
                      style: TextStyle(
                        color: colorScheme.onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                    if (selectedEvents.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Events:',
                          style: TextStyle(
                              fontWeight:
                                  FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...selectedEvents.map((event) =>
                          Container(
                            margin: const EdgeInsets.only(
                                bottom: 8),
                            padding:
                                const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _eventTypeColor(
                                      event.type)
                                  .withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(
                                      10),
                              border: Border.all(
                                  color: _eventTypeColor(
                                          event.type)
                                      .withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                    _eventTypeIcon(
                                        event.type),
                                    size: 18,
                                    color:
                                        _eventTypeColor(
                                            event.type)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal:
                                                    6,
                                                vertical:
                                                    2),
                                            decoration:
                                                BoxDecoration(
                                              color: _eventTypeColor(
                                                      event
                                                          .type)
                                                  .withOpacity(
                                                      0.2),
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          8),
                                            ),
                                            child: Text(
                                              _eventTypeLabel(
                                                  event
                                                      .type),
                                              style: TextStyle(
                                                  fontSize:
                                                      10,
                                                  color: _eventTypeColor(
                                                      event
                                                          .type)),
                                            ),
                                          ),
                                          if (event.notes
                                              .isNotEmpty) ...[
                                            const SizedBox(
                                                width: 6),
                                            Expanded(
                                              child: Text(
                                                event.notes,
                                                style: TextStyle(
                                                    fontSize:
                                                        11,
                                                    color: colorScheme
                                                        .onSurface
                                                        .withOpacity(
                                                            0.6)),
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _deleteEvent(event),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // --- Upcoming Events ---
            if (upcomingEvents.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...upcomingEvents.map((event) {
                final daysUntil = DateTime.parse(event.date)
                    .difference(today)
                    .inDays;
                return Container(
                  margin:
                      const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _eventTypeColor(event.type)
                        .withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                        color: _eventTypeColor(event.type)
                            .withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              _eventTypeColor(event.type)
                                  .withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: Icon(
                            _eventTypeIcon(event.type),
                            size: 20,
                            color: _eventTypeColor(
                                event.type)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold),
                            ),
                            Text(
                              '${event.date} • ${_eventTypeLabel(event.type)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              _eventTypeColor(event.type),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: Text(
                          daysUntil == 0
                              ? 'Today!'
                              : daysUntil == 1
                                  ? 'Tomorrow'
                                  : '$daysUntil days',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // --- Legend ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Practice: ',
                    style: TextStyle(fontSize: 12)),
                ...[0.3, 0.5, 0.75, 1.0].map((opacity) =>
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
                    )),
                const Text('  Events: ',
                    style: TextStyle(fontSize: 12)),
                ...EventType.values.take(3).map((type) =>
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 2),
                      decoration: BoxDecoration(
                        color: _eventTypeColor(type),
                        shape: BoxShape.circle,
                      ),
                    )),
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