import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:yuki_blog_app/features/todo/todo_model.dart';

/// 从博客待办文章解析出的一条远端待办（尚未并入本地存储）。
class RemoteTodo {
  const RemoteTodo({
    required this.id,
    required this.title,
    this.note,
    required this.category,
    this.subject,
    this.group,
    this.dueLabel,
    this.dueDate,
  });

  final String id;
  final String title;
  final String? note;
  final TodoCategory category;

  /// 科目 / 子类（来自文章的 `.todo-subhead`），用于组内按科目子分区。
  final String? subject;

  /// 所属的人 / 组（来自文章的 `.todo-group-title`，如「雪穗的待办」
  /// 「软件2615同学待办」），App 端最顶层分组维度，与网页版一致。
  final String? group;

  final String? dueLabel;
  final DateTime? dueDate;
}

/// 远端待办数据源：拉取并解析博客《待办清单》文章。
abstract class TodoRemoteSource {
  Future<List<RemoteTodo>> fetch();
}

/// 网络数据源：依次尝试线上文章页与 GitHub 原始 markdown（二者都含
/// `.todo-root` 结构），任一成功即解析返回；全部失败抛异常。
///
/// 与课表一致：首选 yiyu14.top（国内最快），回退 raw.githubusercontent /
/// jsDelivr（master 分支的源 markdown，内嵌同样的 HTML 结构）。
class NetworkTodoRemoteSource implements TodoRemoteSource {
  NetworkTodoRemoteSource({
    http.Client? client,
    List<Uri>? urls,
    this.timeout = const Duration(seconds: 8),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        urls = urls ?? defaultUrls;

  static final List<Uri> defaultUrls = [
    Uri.parse('https://yiyu14.top/posts/todo/'),
    Uri.parse(
      'https://raw.githubusercontent.com/cixiy1/Yuki-blog/master/'
      'src/content/posts/todo.md',
    ),
    Uri.parse(
      'https://cdn.jsdelivr.net/gh/cixiy1/Yuki-blog@master/'
      'src/content/posts/todo.md',
    ),
  ];

  final http.Client _client;
  final bool _ownsClient;
  final List<Uri> urls;
  final Duration timeout;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  @override
  Future<List<RemoteTodo>> fetch() async {
    final failures = <String>[];
    for (final url in urls) {
      try {
        final resp = await _client.get(url).timeout(timeout);
        if (resp.statusCode != 200) {
          failures.add('${url.host}: HTTP ${resp.statusCode}');
          continue;
        }
        final html = utf8.decode(resp.bodyBytes);
        final items = parseTodoHtml(html);
        if (items.isEmpty) {
          failures.add('${url.host}: 未解析到待办项');
          continue;
        }
        return items;
      } catch (e) {
        failures.add('${url.host}: $e');
      }
    }
    throw TodoNetworkException('待办文章全部拉取失败', failures);
  }
}

/// 网络拉取失败时抛出，[failures] 记录每个候选地址的失败原因。
class TodoNetworkException implements Exception {
  const TodoNetworkException(this.message, this.failures);
  final String message;
  final List<String> failures;

  @override
  String toString() => 'TodoNetworkException: $message\n${failures.join('\n')}';
}

/// 解析博客待办文章 HTML（渲染页或原始 markdown 均含 `.todo-root`）。
List<RemoteTodo> parseTodoHtml(String html) {
  final doc = parse(html);
  final root = doc.querySelector('.todo-root');
  if (root == null) return const [];

  final out = <RemoteTodo>[];
  for (final group in root.querySelectorAll('.todo-group')) {
    final titleEl = group.querySelector('.todo-group-title');
    final groupTitle = titleEl?.text.trim();
    final category = _mapCategory(groupTitle ?? '');
    _walk(group, category, groupTitle, null, null, out);
  }
  return out;
}

void _walk(
  Element node,
  TodoCategory category,
  String? group,
  String? subhead,
  String? note,
  List<RemoteTodo> out,
) {
  // 按文档顺序遍历，subhead / note 在遇到的那一刻就地更新，并向下与向后续
  // 兄弟节点传播——这样子标题、备注能正确归属其后出现的待办项。
  for (final child in node.children) {
    if (child.classes.contains('todo-subhead')) {
      subhead = child.text.trim();
      _walk(child, category, group, subhead, note, out);
    } else if (child.classes.contains('todo-note')) {
      note = child.text.trim();
      _walk(child, category, group, subhead, note, out);
    } else if (child.classes.contains('todo-item')) {
      final item = _extractItem(child, category, group, subhead, note);
      if (item != null) out.add(item);
      // 不向 item 内部递归（其后代是 label 细节，不是待办项）
    } else {
      _walk(child, category, group, subhead, note, out);
    }
  }
}

RemoteTodo? _extractItem(
  Element item,
  TodoCategory category,
  String? group,
  String? subhead,
  String? note,
) {
  final input = item.querySelector('input.todo-check');
  final id = input?.attributes['data-todo-id'];
  if (id == null || id.isEmpty) return null;

  final textEl = item.querySelector('.todo-text');
  if (textEl == null) return null;
  // 去掉 .todo-status 的状态文案，拿到纯标题。
  final cloned = textEl.clone(true);
  cloned.querySelector('.todo-status')?.remove();
  final title = cloned.text.trim();
  if (title.isEmpty) return null;

  final status = item.querySelector('.todo-status')?.text.trim();

  final parts = <String>[];
  if (subhead != null && subhead.isNotEmpty) parts.add(subhead);
  if (note != null && note.isNotEmpty) parts.add(note);
  final mergedNote = parts.isEmpty ? null : parts.join(' · ');

  return RemoteTodo(
    id: id,
    title: title,
    note: mergedNote,
    category: category,
    subject: subhead,
    group: group,
    dueLabel: status,
    dueDate: status == null ? null : _parseDueDate(status),
  );
}

TodoCategory _mapCategory(String title) {
  if (title.contains('雪穗')) return TodoCategory.personal;
  if (title.contains('党务') ||
      title.contains('入党') ||
      title.contains('党员')) {
    return TodoCategory.party;
  }
  if (title.contains('班长') ||
      title.contains('同学') ||
      title.contains('2615')) {
    return TodoCategory.classAffairs;
  }
  return TodoCategory.other;
}

/// 从「第8周周日 10.25 23:00 关闭」这类文案里抠出第一个 M.D / M月D日，
/// 按当年构造日期（便于逾期高亮）。抽不到返回 null。
DateTime? _parseDueDate(String label) {
  final m = RegExp(r'(\d{1,2})[.月/](\d{1,2})').firstMatch(label);
  if (m == null) return null;
  final month = int.tryParse(m.group(1)!);
  final day = int.tryParse(m.group(2)!);
  if (month == null ||
      day == null ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31) {
    return null;
  }
  final now = DateTime.now();
  try {
    return DateTime(now.year, month, day);
  } on ArgumentError {
    return null;
  }
}
