import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'todo_model.dart';

/// 待办存储的聚合快照：条目列表 + 已删除的远端 id（墓碑）。
///
/// 远端文章删除/用户删除某条远端待办后，靠 [deletedRemoteIds] 记一笔，
/// 下次拉取时不再把它复活；本地自建项不在墓碑范围内。
class TodoStore {
  const TodoStore({
    this.items = const [],
    this.deletedRemoteIds = const {},
  });

  final List<TodoItem> items;
  final Set<String> deletedRemoteIds;

  Map<String, dynamic> toJson() => {
        'items': [for (final e in items) e.toJson()],
        'deletedRemoteIds': [for (final e in deletedRemoteIds) e],
      };

  /// 兼容旧版纯数组格式（只有 items，无墓碑）。
  factory TodoStore.fromJson(dynamic json) {
    if (json is List) {
      return TodoStore(
        items: [
          for (final e in json)
            if (e is Map<String, dynamic>) TodoItem.fromJson(e)
        ],
      );
    }
    if (json is Map) {
      final itemsRaw = json['items'];
      final delRaw = json['deletedRemoteIds'];
      return TodoStore(
        items: itemsRaw is List
            ? [
                for (final e in itemsRaw)
                  if (e is Map<String, dynamic>) TodoItem.fromJson(e)
              ]
            : const [],
        deletedRemoteIds: delRaw is List
            ? {for (final e in delRaw) if (e is String) e}
            : const {},
      );
    }
    return const TodoStore();
  }
}

/// 待办存储接口。页面只依赖这个抽象，换实现（文件 / 内存 / 云）不动 UI。
abstract class TodoStorage {
  /// 读出全部待办与墓碑。
  Future<TodoStore> load();

  /// 全量覆盖写入。
  Future<void> save(TodoStore store);
}

/// 内存实现，仅供测试与预览使用。
class MemoryTodoStorage implements TodoStorage {
  MemoryTodoStorage([TodoStore? initial])
      : _store = initial ?? const TodoStore();

  TodoStore _store;

  TodoStore get store => _store;

  @override
  Future<TodoStore> load() async => _store;

  @override
  Future<void> save(TodoStore store) async => _store = store;
}

/// 本地文件实现：在应用文档目录存一份 `todos.json`。
///
/// 不引入额外依赖（[path_provider] 已在工程依赖中，JSON 用标准库）。
/// 读取失败（文件不存在 / 损坏）一律返回空存储，不因此让页面报错。
class FileTodoStorage implements TodoStorage {
  FileTodoStorage(this.directory);

  /// 目录通常是 `getApplicationDocumentsDirectory()` 的结果（异步获取）。
  final Future<Directory> directory;

  Future<File> get _file async {
    final dir = await directory;
    return File('${dir.path}/todos.json');
  }

  @override
  Future<TodoStore> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return const TodoStore();
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      return TodoStore.fromJson(decoded);
    } catch (_) {
      return const TodoStore();
    }
  }

  @override
  Future<void> save(TodoStore store) async {
    final file = await _file;
    await file.writeAsString(jsonEncode(store.toJson()));
  }
}
