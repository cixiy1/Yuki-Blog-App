import 'dart:convert';

import 'package:web/web.dart' as web;

import 'api_client.dart';
import 'json_store_base.dart';

/// Web 实现：`localStorage['campus.v1.<key>']`。
///
/// 浏览器配额通常 5MB，图片 base64 很容易吃满。写失败一律抛 413，
/// 让界面能给出「去设置里重置演示数据」的提示，而不是静默丢数据。
class LocalStorageJsonStore implements JsonStore {
  static const String prefix = 'campus.v1.';

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final raw = web.window.localStorage.getItem('$prefix$key');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    try {
      web.window.localStorage.setItem('$prefix$key', jsonEncode(value));
    } catch (_) {
      throw const ApiException(
        413,
        'STORAGE_FULL',
        '本地存储空间已满（浏览器上限约 5MB），请在设置里重置演示数据',
      );
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      web.window.localStorage.removeItem('$prefix$key');
    } catch (_) {
      // 忽略：删不掉不影响主流程
    }
  }

  @override
  bool get isPersistent => true;
}

JsonStore createJsonStore() => LocalStorageJsonStore();
