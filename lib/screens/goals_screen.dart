import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Goal {
  final String id;
  String title;
  int targetMinutes;
  bool isCompleted;
  String completedDate;

  Goal({
    required this.id,
    required this.title,
    required this.targetMinutes,
    this.isCompleted = false,
    this.completedDate = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetMinutes': targetMinutes,
        'isCompleted': isCompleted,
        'completedDate': completedDate,
      };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'],
        title: json['title'],
        targetMinutes: json['targetMinutes'],
        isCompleted: json['isCompleted'] ?? false,
        completedDate: json['completedDate'] ?? '',
      );
}

class CompletedGoal {
  final String title;
  final String date;
  final int targetMinutes;

  CompletedGoal({
    required this.title,
    required this.date,
    required this.targetMinutes,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date,
        'targetMinutes': targetMinutes,
      };

  factory CompletedGoal.fromJson(Map<String, dynamic> json) =>
      CompletedGoal(
        title: json['title'],
        date: json['date'],
        targetMinutes: json['targetMinutes'],
      );
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal> _goals = [];
  List<CompletedGoal> _history = [];
  bool _showHistory = false;
  final TextEditingController _titleController =
      TextEditingController();
  int _targetMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('goals') ?? [];
    final historyData =
        prefs.getStringList('goalHistory') ?? [];

    setState(() {
      _goals = data
          .map((g) => Goal.fromJson(jsonDecode(g)))
          .toList();
      _history = historyData
          .map((h) => CompletedGoal.fromJson(jsonDecode(h)))
          .toList()
          .reversed
          .toList();
    });
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data =
        _goals.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList('goals', data);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _history.reversed
        .map((h) => jsonEncode(h.toJson()))
        .toList();
    await prefs.setStringList('goalHistory', data);
  }

  void _addGoal() {
    if (_titleController.text.trim().isEmpty) return;
    final newGoal = Goal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      targetMinutes: _targetMinutes,
    );
    setState(() => _goals.add(newGoal));
    _saveGoals();
    _titleController.clear();
    _targetMinutes = 30;
    Navigator.pop(context);
  }

  void _deleteGoal(String id) {
    setState(() => _goals.removeWhere((g) => g.id == id));
    _saveGoals();
  }

  void _toggleGoal(String id) async {
    final goal = _goals.firstWhere((g) => g.id == id);
    final wasCompleted = goal.isCompleted;

    setState(() {
      goal.isCompleted = !goal.isCompleted;
      goal.completedDate = goal.isCompleted
          ? DateTime.now().toString().substring(0, 10)
          : '';
    });

    // Add to history when completing a goal
    if (!wasCompleted && goal.isCompleted) {
      final historyEntry = CompletedGoal(
        title: goal.title,
        date: DateTime.now().toString().substring(0, 16),
        targetMinutes: goal.targetMinutes,
      );
      setState(() => _history.insert(0, historyEntry));
      await _saveHistory();
    }

    await _saveGoals();
  }

  void _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
            'Are you sure you want to clear all goal completion history?'),
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
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _history.clear());
      await _saveHistory();
    }
  }

  void _showAddGoalDialog() {
    _titleController.clear();
    _targetMinutes = 30;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Goal Title',
                  hintText: 'e.g. Practice scales daily',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Daily Target: $_targetMinutes minutes',
                style: const TextStyle(fontSize: 16),
              ),
              Slider(
                value: _targetMinutes.toDouble(),
                min: 5,
                max: 180,
                divisions: 35,
                label: '$_targetMinutes min',
                activeColor: Colors.orange,
                onChanged: (val) => setDialogState(
                    () => _targetMinutes = val.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _addGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Goal'),
            ),
          ],
        ),
      ),
    );
  }

  double get _completionRate {
    if (_goals.isEmpty) return 0;
    final completed =
        _goals.where((g) => g.isCompleted).length;
    return completed / _goals.length;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          // Toggle between goals and history
          IconButton(
            icon: Icon(_showHistory
                ? Icons.flag
                : Icons.history),
            onPressed: () =>
                setState(() => _showHistory = !_showHistory),
            tooltip: _showHistory
                ? 'Show Goals'
                : 'Show History',
          ),
        ],
      ),
      floatingActionButton: _showHistory
          ? null
          : FloatingActionButton(
              onPressed: _showAddGoalDialog,
              backgroundColor: Colors.orange,
              child:
                  const Icon(Icons.add, color: Colors.white),
            ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: _showHistory
            ? _buildHistory(colorScheme)
            : _buildGoals(colorScheme),
      ),
    );
  }

  Widget _buildGoals(ColorScheme colorScheme) {
    return Column(
      children: [

        // --- Progress Overview ---
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.orange.withOpacity(0.4),
                width: 2),
          ),
          child: Column(
            children: [
              Text(
                '${(_completionRate * 100).round()}% Complete',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _completionRate,
                backgroundColor:
                    Colors.orange.withOpacity(0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(
                        Colors.orange),
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 8),
              Text(
                '${_goals.where((g) => g.isCompleted).length} of ${_goals.length} goals completed today',
                style: TextStyle(
                  color:
                      colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showHistory = true),
                  child: Text(
                    'View completion history (${_history.length} total)',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'My Goals',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: _goals.isEmpty
              ? Center(
                  child: Text(
                    'No goals yet!\nTap + to add your first goal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurface
                          .withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    return Card(
                      margin:
                          const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Checkbox(
                          value: goal.isCompleted,
                          activeColor: Colors.orange,
                          onChanged: (_) =>
                              _toggleGoal(goal.id),
                        ),
                        title: Text(
                          goal.title,
                          style: TextStyle(
                            decoration: goal.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          goal.completedDate.isNotEmpty
                              ? '${goal.targetMinutes} min/day • Completed ${goal.completedDate}'
                              : '${goal.targetMinutes} min / day',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () =>
                              _deleteGoal(goal.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistory(ColorScheme colorScheme) {
    return Column(
      children: [

        // --- History Header ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events,
                  color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_history.length} Goals Completed',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'All time goal completions',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (_history.isNotEmpty)
                TextButton(
                  onPressed: _clearHistory,
                  child: const Text('Clear',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 64,
                          color: colorScheme.onSurface
                              .withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No completed goals yet!\nCheck off a goal to start your history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface
                              .withOpacity(0.5),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Card(
                      margin:
                          const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.check,
                              color: Colors.white,
                              size: 18),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${item.targetMinutes} min/day target'),
                        trailing: Text(
                          item.date,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}