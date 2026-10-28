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

/// 一条待办的来历：来自博客文章（远端）还是本机新建（本地）。
enum TodoSource {
  remote,
  local,
}

/// 单条待办。可序列化到本地 JSON 文件。
class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    this.note,
    this.subject,
    this.group,
    this.category = TodoCategory.other,
    this.done = false,
    DateTime? createdAt,
    this.startDate,
    this.dueDate,
    this.dueLabel,
    this.source = TodoSource.local,
    this.remoteId,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String? note;

  /// 科目 / 子类（来自博客文章的 `.todo-subhead`），用于组内按科目子分区展示。
  final String? subject;

  /// 所属的人 / 组（来自博客文章的 `.todo-group-title`，如「雪穗的待办」
  /// 「软件2615同学待办」）。这是与网页版一致的最顶层分组维度。
  /// 本地自建项可留空，展示时回退到 [category] 对应的默认组标签。
  final String? group;

  /// 最顶层分组展示用的标签：优先用 [group]，缺省回退到分类默认组名。
  String get groupLabel => group ?? _defaultGroupFor(category);

  /// 分类对应的默认组名（本地自建项、或无 group 信息时的兜底分组）。
  static String _defaultGroupFor(TodoCategory c) => switch (c) {
        TodoCategory.classAffairs => '班级事务',
        TodoCategory.party => '党务',
        TodoCategory.personal => '我的待办',
        TodoCategory.other => '其他',
      };

  final TodoCategory category;
  final bool done;
  final DateTime createdAt;

  /// 本地设定的开始日期（新建/编辑时选日期）。
  final DateTime? startDate;

  /// 本地设定的绝对截止日（新建/编辑时选日期）。
  final DateTime? dueDate;

  /// 远端文章里给出的截止文案（如「第8周周日 10.25 23:00 关闭」），
  /// 未必能解析成绝对日期，原样保留用于展示。
  final String? dueLabel;

  /// 来历：远端文章同步来的，还是本机新建的。
  final TodoSource source;

  /// 远端文章里该条目的稳定 id（博客 `data-todo-id`）。本地新建项为 null。
  final String? remoteId;

  TodoItem copyWith({
    String? title,
    String? note,
    String? subject,
    String? group,
    TodoCategory? category,
    bool? done,
    DateTime? dueDate,
    bool clearDue = false,
    DateTime? startDate,
    bool clearStart = false,
    String? dueLabel,
    TodoSource? source,
    String? remoteId,
  }) =>
      TodoItem(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        subject: subject ?? this.subject,
        group: group ?? this.group,
        category: category ?? this.category,
        done: done ?? this.done,
        createdAt: createdAt,
        dueDate: clearDue ? null : (dueDate ?? this.dueDate),
        startDate: clearStart ? null : (startDate ?? this.startDate),
        dueLabel: dueLabel ?? this.dueLabel,
        source: source ?? this.source,
        remoteId: remoteId ?? this.remoteId,
      );

  /// 展示用的截止文案：优先远端原文，其次按本地日期算。
  String? dueText({bool done = false}) {
    if (dueLabel != null && dueLabel!.isNotEmpty) return dueLabel;
    if (dueDate != null) return formatDueLabel(dueDate!, done: done);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'subject': subject,
        'group': group,
        'category': category.name,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
        'startDate': startDate?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'dueLabel': dueLabel,
        'source': source.name,
        'remoteId': remoteId,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String?;
    final category = TodoCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => TodoCategory.other,
    );
    final sourceName = json['source'] as String?;
    final source = TodoSource.values.firstWhere(
      (s) => s.name == sourceName,
      orElse: () => TodoSource.local,
    );
    final createdRaw = json['createdAt'] as String?;
    final startRaw = json['startDate'] as String?;
    final dueRaw = json['dueDate'] as String?;
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
      subject: json['subject'] as String?,
      group: json['group'] as String?,
      category: category,
      done: json['done'] as bool? ?? false,
      createdAt: createdRaw == null ? null : DateTime.tryParse(createdRaw),
      startDate: startRaw == null ? null : DateTime.tryParse(startRaw),
      dueDate: dueRaw == null ? null : DateTime.tryParse(dueRaw),
      dueLabel: json['dueLabel'] as String?,
      source: source,
      remoteId: json['remoteId'] as String?,
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

/// 开始日的展示文案：今天 / 明天 / N月N日。
String formatStartLabel(DateTime start) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startDay = DateTime(start.year, start.month, start.day);
  final diff = startDay.difference(today).inDays;
  if (diff == 0) return '今天开始';
  if (diff == 1) return '明天开始';
  return '${start.month}月${start.day}日开始';
}
