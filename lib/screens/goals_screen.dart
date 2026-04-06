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
  bool _showCompleted = false;

  static const _purple = Color(0xFF6B21FF);
  static const _darkBg = Color(0xFF0D0D1A);
  static const _cardBg = Color(0xFF1A0A4E);
  static const _cardBg2 = Color(0xFF2D1B69);

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('longTermGoals') ?? [];
    setState(() {
      _goals = data.map((g) => Goal.fromJson(jsonDecode(g))).toList();
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
        return const Color(0xFF00BFA5);
      case GoalCategory.weekly:
        return const Color(0xFF2196F3);
      case GoalCategory.monthly:
        return const Color(0xFF9C27B0);
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
      final diff = DateTime.parse(dueDate)
          .difference(DateTime.now())
          .inDays;
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
      return Colors.greenAccent;
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
        return now.add(const Duration(days: 7)).toString().substring(0, 10);
      case GoalCategory.monthly:
        return now.add(const Duration(days: 30)).toString().substring(0, 10);
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
        backgroundColor: _cardBg,
        title: const Text('Delete Goal',
            style: TextStyle(color: Colors.white)),
        content: Text('Delete "${goal.title}"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
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
    GoalCategory selectedCategory = preselected ?? GoalCategory.weekly;
    DateTime selectedDueDate =
        DateTime.parse(_defaultDueDate(selectedCategory));
    final titleController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          title: const Text('Add Goal',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Goal *',
                    labelStyle:
                        const TextStyle(color: Colors.white60),
                    hintText: 'e.g. Practice scales every day',
                    hintStyle:
                        const TextStyle(color: Colors.white30),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _purple.withOpacity(0.4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _purple.withOpacity(0.4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _purple),
                    ),
                    prefixIcon: const Icon(Icons.flag,
                        color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Category',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: GoalCategory.values.map((cat) {
                    final isSelected = selectedCategory == cat;
                    final color = _categoryColor(cat);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedCategory = cat;
                              selectedDueDate = DateTime.parse(
                                  _defaultDueDate(cat));
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color
                                  : color.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(10),
                              border: Border.all(
                                  color: color.withOpacity(0.4)),
                            ),
                            child: Column(
                              children: [
                                Icon(_categoryIcon(cat),
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : color),
                                const SizedBox(height: 4),
                                Text(
                                  _categoryLabel(cat),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white
                                        : color,
                                    fontWeight: FontWeight.bold,
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
                const Text('Due Date',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDueDate,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 1)),
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
                          color: _purple.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(12),
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
                              fontSize: 15,
                              color: Colors.white),
                        ),
                        const Spacer(),
                        const Icon(Icons.edit,
                            size: 16, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Notes (optional)',
                    labelStyle:
                        const TextStyle(color: Colors.white60),
                    hintText: 'e.g. Focus on technique',
                    hintStyle:
                        const TextStyle(color: Colors.white30),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _purple.withOpacity(0.4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _purple.withOpacity(0.4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _purple),
                    ),
                    prefixIcon: const Icon(Icons.notes,
                        color: Colors.white54),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
    final totalActive = _goals.where((g) => !g.isCompleted).length;
    final totalCompleted = _goals.where((g) => g.isCompleted).length;

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        title: const Text('Goals',
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
          GestureDetector(
            onTap: () =>
                setState(() => _showCompleted = !_showCompleted),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _showCompleted
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showCompleted ? 'Hide Done' : 'Show Done',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGoalDialog(),
        backgroundColor: const Color(0xFFFF6B35),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- Summary Cards ---
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4A2600),
                          Color(0xFF6D3800)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.orange.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$totalActive',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.orange,
                          ),
                        ),
                        const Text('Active',
                            style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00352A),
                          Color(0xFF00574A)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.green.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$totalCompleted',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.greenAccent,
                          ),
                        ),
                        const Text('Completed',
                            style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Icon(_categoryIcon(cat),
                                size: 18, color: color),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _categoryLabel(cat),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_goals.where((g) => g.category == cat && !g.isCompleted).length}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showAddGoalDialog(cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.add,
                                  size: 14, color: color),
                              const SizedBox(width: 4),
                              Text('Add',
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Goals or empty state
                  if (goals.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_cardBg, _cardBg2],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: color.withOpacity(0.2)),
                      ),
                      child: Text(
                        'No ${_categoryLabel(cat).toLowerCase()} goals yet — tap Add!',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white38),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ...goals.map((goal) =>
                        _buildGoalCard(goal, color)),
                  const SizedBox(height: 20),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal, Color color) {
    final daysLeft = _daysRemaining(goal.dueDate);
    final dateColor = _dueDateColor(goal.dueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: goal.isCompleted
              ? [
                  Colors.green.withOpacity(0.12),
                  Colors.green.withOpacity(0.06),
                ]
              : [_cardBg, _cardBg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: goal.isCompleted
              ? Colors.green.withOpacity(0.35)
              : color.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: goal.isCompleted
                ? Colors.green.withOpacity(0.1)
                : color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
                  color: goal.isCompleted ? Colors.green : color,
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
                        ? Colors.white30
                        : Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 16,
                    color: Colors.red.withOpacity(0.7)),
                onPressed: () => _deleteGoal(goal),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 11, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      goal.dueDate,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38),
                    ),
                    const SizedBox(width: 8),
                    if (!goal.isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: dateColor.withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: Text(
                          daysLeft,
                          style: TextStyle(
                            fontSize: 10,
                            color: dateColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (goal.isCompleted)
                      const Text(
                        '✓ Done',
                        style: TextStyle(
                            fontSize: 11, color: Colors.green),
                      ),
                  ],
                ),
                if (goal.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    goal.notes,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white54),
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