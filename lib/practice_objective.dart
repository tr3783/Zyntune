import 'dart:convert';

class PracticeObjective {
  final String id;
  String pieceName;
  String section;
  List<ChecklistItem> checklistItems;
  bool completed;

  PracticeObjective({
    required this.id,
    this.pieceName = '',
    this.section = '',
    List<ChecklistItem>? checklistItems,
    this.completed = false,
  }) : checklistItems = checklistItems ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'pieceName': pieceName,
        'section': section,
        'checklistItems':
            checklistItems.map((c) => c.toJson()).toList(),
        'completed': completed,
      };

  factory PracticeObjective.fromJson(
          Map<String, dynamic> json) =>
      PracticeObjective(
        id: json['id'] ??
            DateTime.now()
                .millisecondsSinceEpoch
                .toString(),
        pieceName: json['pieceName'] ?? json['songName'] ?? '',
        section: json['section'] ?? '',
        checklistItems:
            (json['checklistItems'] as List? ?? [])
                .map((c) => ChecklistItem.fromJson(c))
                .toList(),
        completed: json['completed'] ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  static PracticeObjective fromJsonString(String s) =>
      PracticeObjective.fromJson(jsonDecode(s));
}

class ChecklistItem {
  final String id;
  String text;
  bool checked;

  ChecklistItem({
    required this.id,
    required this.text,
    this.checked = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'checked': checked,
      };

  factory ChecklistItem.fromJson(
          Map<String, dynamic> json) =>
      ChecklistItem(
        id: json['id'] ??
            DateTime.now()
                .millisecondsSinceEpoch
                .toString(),
        text: json['text'] ?? '',
        checked: json['checked'] ?? false,
      );
}