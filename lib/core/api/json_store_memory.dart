import 'json_store_base.dart';

/// 内存实现。Web 之外的兜底 / 单元测试用。
class MemoryJsonStore implements JsonStore {
  MemoryJsonStore([Map<String, Map<String, dynamic>>? initial])
      : _data = {...?initial};

  final Map<String, Map<String, dynamic>> _data;

  Map<String, Map<String, dynamic>> get snapshot => _data;

  @override
  Future<Map<String, dynamic>?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, Map<String, dynamic> value) async =>
      _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  bool get isPersistent => false;
}

JsonStore createJsonStore() => MemoryJsonStore();
