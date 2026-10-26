import 'package:flutter/material.dart';

/// 待办分类。预设四项，覆盖班级 App 的主要使用场景。
enum TodoCategory {
  classAffairs('班级事务', Icons.groups_outlined),
  party('党务', Icons.flag_outlined),
  personal('个人', Icons.person_outline),
  other('其他', Icons.label_outline);

  const TodoCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// 按展示顺序返回所有分类（用于筛选 / 选择）。
  static List<TodoCategory> get valuesOrdered =>
      [classAffairs, party, personal, other];
}

/// 单条待办。可序列化到本地 JSON 文件。
class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    this.note,
    this.category = TodoCategory.other,
    this.done = false,
    DateTime? createdAt,
    this.dueDate,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String? note;
  final TodoCategory category;
  final bool done;
  final DateTime createdAt;
  final DateTime? dueDate;

  TodoItem copyWith({
    String? title,
    String? note,
    TodoCategory? category,
    bool? done,
    DateTime? dueDate,
    bool clearDue = false,
  }) =>
      TodoItem(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        category: category ?? this.category,
        done: done ?? this.done,
        createdAt: createdAt,
        dueDate: clearDue ? null : (dueDate ?? this.dueDate),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'category': category.name,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String?;
    final category = TodoCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => TodoCategory.other,
    );
    final createdRaw = json['createdAt'] as String?;
    final dueRaw = json['dueDate'] as String?;
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
      category: category,
      done: json['done'] as bool? ?? false,
      createdAt: createdRaw == null
          ? null
          : DateTime.tryParse(createdRaw),
      dueDate: dueRaw == null ? null : DateTime.tryParse(dueRaw),
    );
  }
}

/// 截止日相对今天的文案：逾期 / 今天 / N月N日。
String formatDueLabel(DateTime due, {bool done = false}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final diff = dueDay.difference(today).inDays;
  if (diff < 0) return '逾期 ${-diff} 天';
  if (diff == 0) return '今天截止';
  return '${due.month}月${due.day}日截止';
}
