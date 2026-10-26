import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'todo_model.dart';

/// 待办存储接口。页面只依赖这个抽象，换实现（文件 / 内存 / 云）不动 UI。
abstract class TodoStorage {
  /// 读出全部待办（顺序由存储层保证：写回前 UI 已排好序）。
  Future<List<TodoItem>> load();

  /// 全量覆盖写入。
  Future<void> save(List<TodoItem> items);
}

/// 内存实现，仅供测试与预览使用。
class MemoryTodoStorage implements TodoStorage {
  MemoryTodoStorage([List<TodoItem>? initial]) : _items = List.of(initial ?? const []);

  List<TodoItem> _items;

  List<TodoItem> get items => List.of(_items);

  @override
  Future<List<TodoItem>> load() async => List.of(_items);

  @override
  Future<void> save(List<TodoItem> items) async {
    _items = List.of(items);
  }
}

/// 本地文件实现：在应用文档目录存一份 `todos.json`。
///
/// 不引入额外依赖（[path_provider] 已在工程依赖中，JSON 用标准库）。
/// 读取失败（文件不存在 / 损坏）一律返回空列表，不因此让页面报错。
class FileTodoStorage implements TodoStorage {
  FileTodoStorage(this.directory);

  /// 目录通常是 `getApplicationDocumentsDirectory()` 的结果（异步获取）。
  final Future<Directory> directory;

  Future<File> get _file async {
    final dir = await directory;
    return File('${dir.path}/todos.json');
  }

  @override
  Future<List<TodoItem>> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return const [];
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map<String, dynamic>) TodoItem.fromJson(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<TodoItem> items) async {
    final file = await _file;
    await file.writeAsString(
      jsonEncode([for (final e in items) e.toJson()]),
    );
  }
}
