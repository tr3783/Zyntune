import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../streak_helper.dart';
import '../timer_service.dart';
import '../practice_objective.dart';

class PracticeSession {
  final String id;
  final String date;
  int durationMinutes;
  String notes;

  PracticeSession({
    required this.id,
    required this.date,
    required this.durationMinutes,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'durationMinutes': durationMinutes,
        'notes': notes,
      };

  factory PracticeSession.fromJson(Map<String, dynamic> json) =>
      PracticeSession(
        id: json['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        date: json['date'],
        durationMinutes: json['durationMinutes'],
        notes: json['notes'] ?? '',
      );
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _timerService = TimerService();
  final List<int> _presets = [5, 10, 15, 20, 30, 45, 60];
  int _selectedPreset = 15;
  final TextEditingController _notesController =
      TextEditingController();
  final TextEditingController _customMinutesController =
      TextEditingController();
  List<PracticeSession> _sessions = [];
  List<PracticeObjective> _objectives = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _loadObjectives();
    _timerService.addListener(_onTimerUpdate);
  }

  void _onTimerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timerService.removeListener(_onTimerUpdate);
    _notesController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadObjectives() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr =
        DateTime.now().toString().substring(0, 10);
    final todayKey = 'objectives_$todayStr';
    final objData = prefs.getStringList(todayKey) ?? [];
    setState(() {
      _objectives = objData
          .map((s) => PracticeObjective.fromJsonString(s))
          .toList();
    });
  }

  Future<void> _saveObjectives() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr =
        DateTime.now().toString().substring(0, 10);
    final todayKey = 'objectives_$todayStr';
    await prefs.setStringList(todayKey,
        _objectives.map((o) => o.toJsonString()).toList());
  }

  void _toggleChecklistItem(
      PracticeObjective obj, ChecklistItem item) {
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
    final data =
        prefs.getStringList('practiceSessions') ?? [];
    setState(() {
      _sessions = data
          .map((s) =>
              PracticeSession.fromJson(jsonDecode(s)))
          .toList()
          .reversed
          .toList();
    });
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final reversed = _sessions.reversed.toList();
    final data =
        reversed.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('practiceSessions', data);
  }

  Future<void> _saveNewSession() async {
    final newSession = PracticeSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now().toString().substring(0, 16),
      durationMinutes:
          (_timerService.elapsed / 60).floor(),
      notes: _notesController.text.trim(),
    );
    setState(() => _sessions.insert(0, newSession));
    await _saveSessions();
    await StreakHelper.updateStreak();
  }

  Future<void> _showSaveDialog() async {
    _notesController.clear();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Practice Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Duration: ${_formatTime(_timerService.elapsed)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'What did you work on?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveNewSession();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(PracticeSession session) {
    final editNotesController =
        TextEditingController(text: session.notes);
    final editMinutesController = TextEditingController(
        text: session.durationMinutes.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(session.date,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            TextField(
              controller: editMinutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: editNotesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'What did you work on?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              final mins = int.tryParse(
                      editMinutesController.text) ??
                  session.durationMinutes;
              setState(() {
                session.durationMinutes = mins;
                session.notes =
                    editNotesController.text.trim();
              });
              await _saveSessions();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteSession(PracticeSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
            'Delete the ${session.durationMinutes} min session on ${session.date}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _sessions
          .removeWhere((s) => s.id == session.id));
      await _saveSessions();
    }
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final elapsed = _timerService.elapsed;
    final isRunning = _timerService.isRunning;
    final isPaused = _timerService.isPaused;
    final countdownActive = _timerService.countdownActive;
    final countdownFinished =
        _timerService.countdownFinished;
    final countdownRemaining =
        _timerService.countdownRemaining;
    final countdownProgress =
        _timerService.countdownProgress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Timer',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --- TODAY'S OBJECTIVES ---
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text("Today's Objectives",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary)),
                  TextButton.icon(
                    onPressed: _loadObjectives,
                    icon: const Icon(Icons.refresh,
                        size: 16),
                    label: const Text('Refresh'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_objectives.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple
                        .withOpacity(0.05),
                    borderRadius:
                        BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.deepPurple
                            .withOpacity(0.2)),
                  ),
                  child: Text(
                    'No objectives set for today.\nAdd them on the home screen!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                )
              else
                ..._objectives.map((obj) =>
                    _buildObjectiveCard(
                        obj, colorScheme)),

              const SizedBox(height: 24),

              // --- STOPWATCH ---
              Text('Stopwatch',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.teal.withOpacity(0.4),
                      width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatTime(elapsed),
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isRunning
                            ? _pauseStopwatch
                            : _startStopwatch,
                        icon: Icon(isRunning
                            ? Icons.pause
                            : Icons.play_arrow),
                        label: Text(isRunning
                            ? 'Pause'
                            : 'Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRunning
                              ? Colors.orange
                              : Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                (isRunning || isPaused)
                                    ? _stopStopwatch
                                    : null,
                            icon: const Icon(Icons.stop),
                            label: const Text(
                                'Stop & Save'),
                            style:
                                ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resetStopwatch,
                            icon:
                                const Icon(Icons.refresh),
                            label: const Text('Reset'),
                            style:
                                OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- COUNTDOWN ---
              Text('Countdown Timer',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary)),
              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _presets.map((min) {
                    final isSelected =
                        _selectedPreset == min;
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$min min'),
                        selected: isSelected,
                        selectedColor:
                            Colors.teal.withOpacity(0.3),
                        onSelected: (_) {
                          setState(() =>
                              _selectedPreset = min);
                          _timerService
                              .setCountdownDuration(min);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Text('Custom: ',
                      style: TextStyle(fontSize: 15)),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _customMinutesController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'min',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8),
                      ),
                      onSubmitted: (val) {
                        final mins = int.tryParse(val);
                        if (mins != null && mins > 0) {
                          setState(() =>
                              _selectedPreset = -1);
                          _timerService
                              .setCountdownDuration(mins);
                          FocusScope.of(context).unfocus();
                        }
                      },
                      onTapOutside: (_) {
                        final mins = int.tryParse(
                            _customMinutesController.text);
                        if (mins != null && mins > 0) {
                          setState(() =>
                              _selectedPreset = -1);
                          _timerService
                              .setCountdownDuration(mins);
                        }
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  const Text(' minutes',
                      style: TextStyle(fontSize: 15)),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: countdownFinished
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: countdownFinished
                        ? Colors.green.withOpacity(0.4)
                        : Colors.orange.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: CircularProgressIndicator(
                            value: countdownProgress,
                            strokeWidth: 10,
                            backgroundColor: Colors.orange
                                .withOpacity(0.2),
                            color: countdownFinished
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        Text(
                          countdownFinished
                              ? 'Done!'
                              : _formatTime(
                                  countdownRemaining),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: countdownActive
                            ? _timerService.pauseCountdown
                            : _timerService.startCountdown,
                        icon: Icon(countdownActive
                            ? Icons.pause
                            : Icons.play_arrow),
                        label: Text(countdownActive
                            ? 'Pause'
                            : 'Start'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: countdownActive
                              ? Colors.orange
                              : Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _timerService.resetCountdown,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Recent Sessions ---
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Sessions',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary)),
                  Text(
                    'Swipe to delete • Tap to edit',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface
                          .withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions yet.\nStart practicing!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface
                              .withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return Dismissible(
                          key: Key(session.id),
                          direction:
                              DismissDirection.endToStart,
                          background: Container(
                            alignment:
                                Alignment.centerRight,
                            padding: const EdgeInsets.only(
                                right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius:
                                  BorderRadius.circular(
                                      12),
                            ),
                            child: const Icon(Icons.delete,
                                color: Colors.white),
                          ),
                          onDismissed: (_) =>
                              _deleteSession(session),
                          child: Card(
                            margin: const EdgeInsets.only(
                                bottom: 8),
                            child: ListTile(
                              onTap: () =>
                                  _showEditDialog(session),
                              leading: const CircleAvatar(
                                backgroundColor:
                                    Colors.teal,
                                child: Icon(
                                    Icons.music_note,
                                    color: Colors.white,
                                    size: 18),
                              ),
                              title: Text(
                                '${session.durationMinutes} min',
                                style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                              subtitle: Text(
                                session.notes.isEmpty
                                    ? session.date
                                    : '${session.date} • ${session.notes}',
                              ),
                              trailing: Row(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: Colors.teal),
                                    onPressed: () =>
                                        _showEditDialog(
                                            session),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons
                                            .delete_outline,
                                        size: 18,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _deleteSession(
                                            session),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildObjectiveCard(
      PracticeObjective obj, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: obj.completed
            ? Colors.green.withOpacity(0.08)
            : Colors.deepPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: obj.completed
              ? Colors.green.withOpacity(0.3)
              : Colors.deepPurple.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    _toggleObjectiveComplete(obj),
                child: Icon(
                  obj.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: obj.completed
                      ? Colors.green
                      : Colors.deepPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      obj.pieceName.isEmpty
                          ? 'Free Practice'
                          : obj.pieceName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: obj.completed
                            ? Colors.green
                            : colorScheme.onSurface,
                        decoration: obj.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (obj.section.isNotEmpty)
                      Text(
                        obj.section,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (obj.checklistItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...obj.checklistItems.map((item) => Padding(
                  padding: const EdgeInsets.only(
                      left: 32, bottom: 4),
                  child: GestureDetector(
                    onTap: () =>
                        _toggleChecklistItem(obj, item),
                    child: Row(
                      children: [
                        Icon(
                          item.checked
                              ? Icons.check_box
                              : Icons
                                  .check_box_outline_blank,
                          size: 16,
                          color: item.checked
                              ? Colors.green
                              : Colors.deepPurple
                                  .withOpacity(0.5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 12,
                              color: item.checked
                                  ? colorScheme.onSurface
                                      .withOpacity(0.4)
                                  : colorScheme.onSurface,
                              decoration: item.checked
                                  ? TextDecoration
                                      .lineThrough
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