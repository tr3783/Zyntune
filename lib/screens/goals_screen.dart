import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum GoalType { weekly, monthly, custom }

class LongTermGoal {
  final String id;
  String title;
  GoalType type;
  String dueDate;
  bool isCompleted;
  String completedDate;
  String notes;

  LongTermGoal({
    required this.id,
    required this.title,
    required this.type,
    required this.dueDate,
    this.isCompleted = false,
    this.completedDate = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'dueDate': dueDate,
        'isCompleted': isCompleted,
        'completedDate': completedDate,
        'notes': notes,
      };

  factory LongTermGoal.fromJson(Map<String, dynamic> json) =>
      LongTermGoal(
        id: json['id'],
        title: json['title'],
        type: GoalType.values.firstWhere(
            (t) => t.name == (json['type'] ?? 'custom'),
            orElse: () => GoalType.custom),
        dueDate: json['dueDate'] ?? '',
        isCompleted: json['isCompleted'] ?? false,
        completedDate: json['completedDate'] ?? '',
        notes: json['notes'] ?? '',
      );
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<LongTermGoal> _goals = [];
  String _filter = 'Active';
  final TextEditingController _titleController =
      TextEditingController();
  final TextEditingController _notesController =
      TextEditingController();
  GoalType _selectedType = GoalType.weekly;
  DateTime _selectedDueDate = DateTime.now()
      .add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('longTermGoals') ?? [];
    setState(() {
      _goals = data
          .map((g) => LongTermGoal.fromJson(jsonDecode(g)))
          .toList();
    });
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data =
        _goals.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList('longTermGoals', data);
  }

  void _addGoal() {
    if (_titleController.text.trim().isEmpty) return;
    final newGoal = LongTermGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      type: _selectedType,
      dueDate: _selectedDueDate.toString().substring(0, 10),
      notes: _notesController.text.trim(),
    );
    setState(() => _goals.insert(0, newGoal));
    _saveGoals();
    _titleController.clear();
    _notesController.clear();
    Navigator.pop(context);
  }

  void _toggleGoal(LongTermGoal goal) {
    setState(() {
      goal.isCompleted = !goal.isCompleted;
      goal.completedDate = goal.isCompleted
          ? DateTime.now().toString().substring(0, 10)
          : '';
    });
    _saveGoals();
  }

  void _deleteGoal(LongTermGoal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Delete "${goal.title}"?'),
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
      setState(() => _goals.remove(goal));
      _saveGoals();
    }
  }

  Future<void> _pickDueDate(StateSetter setDialogState) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime.now(),
      lastDate:
          DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setDialogState(() => _selectedDueDate = picked);
    }
  }

  void _showAddGoalDialog() {
    _titleController.clear();
    _notesController.clear();
    _selectedType = GoalType.weekly;
    _selectedDueDate =
        DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Long-Term Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal',
                    hintText:
                        'e.g. Practice 5 days this week',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Goal Type',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: GoalType.values.map((type) {
                    final label = type == GoalType.weekly
                        ? 'Weekly'
                        : type == GoalType.monthly
                            ? 'Monthly'
                            : 'Custom';
                    final isSelected =
                        _selectedType == type;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          _selectedType = type;
                          if (type == GoalType.weekly) {
                            _selectedDueDate = DateTime.now()
                                .add(const Duration(days: 7));
                          } else if (type ==
                              GoalType.monthly) {
                            _selectedDueDate = DateTime.now()
                                .add(const Duration(days: 30));
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.orange
                              : Colors.orange
                                  .withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.orange
                                  .withOpacity(0.4)),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                const Text('Due Date',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () =>
                      _pickDueDate(setDialogState),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey.shade400),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 18,
                            color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDueDate
                              .toString()
                              .substring(0, 10),
                          style: const TextStyle(
                              fontSize: 15),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText:
                        'e.g. Focus on technique this week',
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

  List<LongTermGoal> get _filteredGoals {
    if (_filter == 'Active') {
      return _goals
          .where((g) => !g.isCompleted)
          .toList();
    } else if (_filter == 'Completed') {
      return _goals.where((g) => g.isCompleted).toList();
    }
    return _goals;
  }

  String _daysRemaining(String dueDate) {
    try {
      final due = DateTime.parse(dueDate);
      final now = DateTime.now();
      final diff = due.difference(now).inDays;
      if (diff < 0) return 'Overdue!';
      if (diff == 0) return 'Due today!';
      if (diff == 1) return '1 day left';
      return '$diff days left';
    } catch (_) {
      return '';
    }
  }

  Color _dueDateColor(String dueDate) {
    try {
      final due = DateTime.parse(dueDate);
      final diff = due.difference(DateTime.now()).inDays;
      if (diff < 0) return Colors.red;
      if (diff <= 2) return Colors.orange;
      return Colors.green;
    } catch (_) {
      return Colors.grey;
    }
  }

  String _typeLabel(GoalType type) {
    switch (type) {
      case GoalType.weekly:
        return 'WEEKLY';
      case GoalType.monthly:
        return 'MONTHLY';
      case GoalType.custom:
        return 'CUSTOM';
    }
  }

  Color _typeColor(GoalType type) {
    switch (type) {
      case GoalType.weekly:
        return Colors.blue;
      case GoalType.monthly:
        return Colors.purple;
      case GoalType.custom:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active =
        _goals.where((g) => !g.isCompleted).length;
    final completed =
        _goals.where((g) => g.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Summary ---
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          Colors.orange.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.orange
                              .withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$active',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight:
                                    FontWeight.bold,
                                color: Colors.orange)),
                        const Text('Active',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          Colors.green.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.green
                              .withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$completed',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight:
                                    FontWeight.bold,
                                color: Colors.green)),
                        const Text('Completed',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Filter ---
            Row(
              children: ['Active', 'Completed', 'All']
                  .map((f) => Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f),
                          selected: _filter == f,
                          onSelected: (_) =>
                              setState(() => _filter = f),
                          selectedColor: Colors.orange
                              .withOpacity(0.3),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // --- Goals List ---
            Expanded(
              child: _filteredGoals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 64,
                              color: colorScheme.onSurface
                                  .withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'Active'
                                ? 'No active goals!\nTap + to add a goal 🎯'
                                : 'No goals here yet.',
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
                      itemCount: _filteredGoals.length,
                      itemBuilder: (context, index) {
                        final goal =
                            _filteredGoals[index];
                        final daysLeft =
                            _daysRemaining(goal.dueDate);
                        final dateColor =
                            _dueDateColor(goal.dueDate);

                        return Container(
                          margin: const EdgeInsets.only(
                              bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: goal.isCompleted
                                ? Colors.green
                                    .withOpacity(0.08)
                                : colorScheme.onSurface
                                    .withOpacity(0.04),
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                              color: goal.isCompleted
                                  ? Colors.green
                                      .withOpacity(0.3)
                                  : colorScheme.onSurface
                                      .withOpacity(0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        _toggleGoal(goal),
                                    child: Icon(
                                      goal.isCompleted
                                          ? Icons
                                              .check_circle
                                          : Icons
                                              .radio_button_unchecked,
                                      color: goal.isCompleted
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      goal.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.bold,
                                        decoration: goal
                                                .isCompleted
                                            ? TextDecoration
                                                .lineThrough
                                            : null,
                                        color: goal.isCompleted
                                            ? colorScheme
                                                .onSurface
                                                .withOpacity(
                                                    0.5)
                                            : colorScheme
                                                .onSurface,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _deleteGoal(goal),
                                  ),
                                ],
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(
                                        left: 36),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 8,
                                          vertical: 2),
                                      decoration:
                                          BoxDecoration(
                                        color: _typeColor(
                                                goal.type)
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius
                                                .circular(8),
                                      ),
                                      child: Text(
                                        _typeLabel(goal.type),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: _typeColor(
                                              goal.type),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (!goal.isCompleted)
                                      Text(
                                        daysLeft,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: dateColor,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),
                                    if (goal.isCompleted)
                                      Text(
                                        'Completed ${goal.completedDate}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (goal.notes.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(
                                          left: 36, top: 4),
                                  child: Text(
                                    goal.notes,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}