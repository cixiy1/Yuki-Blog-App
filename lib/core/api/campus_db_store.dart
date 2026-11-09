import 'json_store.dart';

/// Mock 后端整库的落盘入口。
///
/// 只暴露「整份读 / 整份写」——报名、发消息、改信用分是跨集合事务，
/// 分集合写会出现半完成状态，所以刻意不提供按集合的接口。
abstract interface class CampusDbStore {
  Future<Map<String, dynamic>?> load();

  Future<void> save(Map<String, dynamic> db);

  Future<void> clear();

  bool get isPersistent;
}

/// 走 [JsonStore] 的默认实现（原生写文件、Web 写 localStorage）。
class JsonCampusDbStore implements CampusDbStore {
  JsonCampusDbStore({JsonStore? store, this.key = 'db'})
      : _store = store ?? createJsonStore();

  final JsonStore _store;
  final String key;

  @override
  Future<Map<String, dynamic>?> load() => _store.read(key);

  @override
  Future<void> save(Map<String, dynamic> db) => _store.write(key, db);

  @override
  Future<void> clear() => _store.delete(key);

  @override
  bool get isPersistent => _store.isPersistent;
}

/// 测试用：只活在内存里，永不碰磁盘。
class MemoryCampusDbStore implements CampusDbStore {
  MemoryCampusDbStore([this._db]);

  Map<String, dynamic>? _db;

  Map<String, dynamic>? get raw => _db;

  int saveCount = 0;

  @override
  Future<Map<String, dynamic>?> load() async => _db;

  @override
  Future<void> save(Map<String, dynamic> db) async {
    _db = db;
    saveCount++;
  }

  @override
  Future<void> clear() async => _db = null;

  @override
  bool get isPersistent => false;
}
