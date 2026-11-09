/// 平台无关的键值 JSON 存储接口。
///
/// 存在的理由：原生要写文件、Web 只能走 localStorage，两者 API 完全不同。
/// 上层（CampusDbStore / TokenStore）只认这个接口。
abstract interface class JsonStore {
  /// 读一个键；不存在或解析失败返回 null。
  Future<Map<String, dynamic>?> read(String key);

  /// 覆盖写一个键。
  Future<void> write(String key, Map<String, dynamic> value);

  Future<void> delete(String key);

  /// 是否真的持久化（内存实现为 false，用于 UI 上提示「重启会丢」）。
  bool get isPersistent;
}
