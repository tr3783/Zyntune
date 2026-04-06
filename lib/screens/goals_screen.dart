import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum GoalCategory { daily, weekly, monthly }

class Goal {
  final String id;
  String title;
  GoalCategory category;
  String dueDate;
  bool isCompleted;
  String completedDate;
  String notes;

  Goal({
    required this.id,
    required this.title,
    required this.category,
    required this.dueDate,
    this.isCompleted = false,
    this.completedDate = '',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'dueDate': dueDate,
        'isCompleted': isCompleted,
        'completedDate': completedDate,
        'notes': notes,
      };

  factory Goal.fromJson(Map<String, dynamic> json) {
    GoalCategory category;
    final raw = json['category'] ?? json['type'] ?? 'weekly';
    if (raw == 'daily') {
      category = GoalCategory.daily;
    } else if (raw == 'monthly') {
      category = GoalCategory.monthly;
    } else {
      category = GoalCategory.weekly;
    }
    return Goal(
      id: json['id'],
      title: json['title'],
      category: category,
      dueDate: json['dueDate'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      completedDate: json['completedDate'] ?? '',
      notes: json['notes'] ?? '',
    );
  }
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal> _goals = [];
  GoalCategory? _filterCategory;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('longTermGoals') ?? [];
    setState(() {
      _goals = data
          .map((g) => Goal.fromJson(jsonDecode(g)))
          .toList();
    });
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('longTermGoals',
        _goals.map((g) => jsonEncode(g.toJson())).toList());
  }

  Color _categoryColor(GoalCategory cat) {
    switch (cat) {
      case GoalCategory.daily:
        return Colors.teal;
      case GoalCategory.weekly:
        return Colors.blue;
      case GoalCategory.monthly:
        return Colors.purple;
    }
  }

  IconData _categoryIcon(GoalCategory cat) {
    switch (cat) {
      case GoalCategory.daily:
        return Icons.today;
      case GoalCategory.weekly:
        return Icons.view_week;
      case GoalCategory.monthly:
        return Icons.calendar_month;
    }
  }

  String _categoryLabel(GoalCategory cat) {
    switch (cat) {
      case GoalCategory.daily:
        return 'Daily';
      case GoalCategory.weekly:
        return 'Weekly';
      case GoalCategory.monthly:
        return 'Monthly';
    }
  }

  String _daysRemaining(String dueDate) {
    try {
      final due = DateTime.parse(dueDate);
      final diff = due.difference(DateTime.now()).inDays;
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
      final diff = DateTime.parse(dueDate)
          .difference(DateTime.now())
          .inDays;
      if (diff < 0) return Colors.red;
      if (diff <= 2) return Colors.orange;
      return Colors.green;
    } catch (_) {
      return Colors.grey;
    }
  }

  String _defaultDueDate(GoalCategory cat) {
    final now = DateTime.now();
    switch (cat) {
      case GoalCategory.daily:
        return now.toString().substring(0, 10);
      case GoalCategory.weekly:
        return now
            .add(const Duration(days: 7))
            .toString()
            .substring(0, 10);
      case GoalCategory.monthly:
        return now
            .add(const Duration(days: 30))
            .toString()
            .substring(0, 10);
    }
  }

  void _toggleGoal(Goal goal) {
    setState(() {
      goal.isCompleted = !goal.isCompleted;
      goal.completedDate = goal.isCompleted
          ? DateTime.now().toString().substring(0, 10)
          : '';
    });
    _saveGoals();
  }

  void _deleteGoal(Goal goal) async {
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

  void _showAddGoalDialog([GoalCategory? preselected]) {
    GoalCategory selectedCategory =
        preselected ?? GoalCategory.weekly;
    DateTime selectedDueDate = DateTime.parse(
        _defaultDueDate(selectedCategory));
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal *',
                    hintText:
                        'e.g. Practice scales every day',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag),
                  ),
                ),
                const SizedBox(height: 16),

                // Category selector
                const Text('Category',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: GoalCategory.values.map((cat) {
                    final isSelected =
                        selectedCategory == cat;
                    final color = _categoryColor(cat);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedCategory = cat;
                              selectedDueDate =
                                  DateTime.parse(
                                      _defaultDueDate(cat));
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets
                                .symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color
                                  : color.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(
                                      10),
                              border: Border.all(
                                  color: color
                                      .withOpacity(0.4)),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                    _categoryIcon(cat),
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : color),
                                const SizedBox(height: 2),
                                Text(
                                  _categoryLabel(cat),
                                  style: TextStyle(
                                    fontSize: 11,
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
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Due date
                const Text('Due Date',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDueDate,
                      firstDate: DateTime.now().subtract(
                          const Duration(days: 1)),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(
                          () => selectedDueDate = picked);
                    }
                  },
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
                        Icon(Icons.calendar_today,
                            size: 18,
                            color: _categoryColor(
                                selectedCategory)),
                        const SizedBox(width: 8),
                        Text(
                          selectedDueDate
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
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. Focus on technique',
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
                final goal = Goal(
                  id: DateTime.now()
                      .millisecondsSinceEpoch
                      .toString(),
                  title: titleController.text.trim(),
                  category: selectedCategory,
                  dueDate: selectedDueDate
                      .toString()
                      .substring(0, 10),
                  notes: notesController.text.trim(),
                );
                setState(() => _goals.insert(0, goal));
                _saveGoals();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _categoryColor(selectedCategory),
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Goal'),
            ),
          ],
        ),
      ),
    );
  }

  List<Goal> _goalsForCategory(GoalCategory cat) {
    return _goals
        .where((g) =>
            g.category == cat &&
            (_showCompleted ? true : !g.isCompleted))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalActive =
        _goals.where((g) => !g.isCompleted).length;
    final totalCompleted =
        _goals.where((g) => g.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          TextButton.icon(
            onPressed: () => setState(
                () => _showCompleted = !_showCompleted),
            icon: Icon(
                _showCompleted
                    ? Icons.visibility_off
                    : Icons.visibility,
                size: 18),
            label: Text(
                _showCompleted ? 'Hide Done' : 'Show Done'),
            style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurface
                    .withOpacity(0.7)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Summary ---
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          Colors.orange.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.orange
                              .withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$totalActive',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          Colors.green.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.green
                              .withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$totalCompleted',
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 24),

            // --- Categories ---
            ...GoalCategory.values.map((cat) {
              final goals = _goalsForCategory(cat);
              final color = _categoryColor(cat);
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Category header
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(
                                6),
                            decoration: BoxDecoration(
                              color:
                                  color.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Icon(
                                _categoryIcon(cat),
                                size: 16,
                                color: color),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _categoryLabel(cat),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  color.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(
                                      10),
                            ),
                            child: Text(
                              '${_goals.where((g) => g.category == cat && !g.isCompleted).length}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight:
                                      FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _showAddGoalDialog(cat),
                        icon: Icon(Icons.add,
                            size: 14, color: color),
                        label: Text('Add',
                            style: TextStyle(
                                color: color,
                                fontSize: 12)),
                        style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Goals in this category
                  if (goals.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin:
                          const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.04),
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                color.withOpacity(0.15)),
                      ),
                      child: Text(
                        'No ${_categoryLabel(cat).toLowerCase()} goals yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface
                              .withOpacity(0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...goals.map((goal) =>
                        _buildGoalCard(goal, color)),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    final daysLeft = _daysRemaining(goal.dueDate);
    final dateColor = _dueDateColor(goal.dueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: goal.isCompleted
            ? Colors.green.withOpacity(0.07)
            : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: goal.isCompleted
              ? Colors.green.withOpacity(0.3)
              : color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleGoal(goal),
                child: Icon(
                  goal.isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: goal.isCompleted
                      ? Colors.green
                      : color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  goal.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    decoration: goal.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    color: goal.isCompleted
                        ? colorScheme.onSurface
                            .withOpacity(0.4)
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.red),
                onPressed: () => _deleteGoal(goal),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 11,
                        color: colorScheme.onSurface
                            .withOpacity(0.4)),
                    const SizedBox(width: 4),
                    Text(
                      goal.dueDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!goal.isCompleted)
                      Text(
                        daysLeft,
                        style: TextStyle(
                          fontSize: 11,
                          color: dateColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (goal.isCompleted)
                      Text(
                        '✓ Done ${goal.completedDate}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
                if (goal.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    goal.notes,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}