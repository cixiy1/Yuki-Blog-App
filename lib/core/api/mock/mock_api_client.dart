import 'dart:async';
import 'dart:math';

import '../../../models/campus/campus_user.dart';
import '../../../models/campus/json_utils.dart';
import '../api_client.dart';
import '../campus_db_store.dart';
import 'mock_db.dart';
import 'mock_request.dart';
import 'mock_router.dart';
import 'mock_seed.dart';
import 'router_registration.dart';

/// 本地「假后端」。
///
/// 请求链路：加载整库 → 人为延迟 → 故障注入 → 路由分发 → handler。
/// 与 [HttpApiClient] 共用 [ApiClient] 契约，所以将来接真后端时
/// 业务代码一行不用改。
class MockApiClient implements ApiClient, MockBackend {
  MockApiClient({
    required this.store,
    this.latency = const Duration(milliseconds: 300),
    this.jitterMs = 100,
    this.injector,
    Random? random,
  }) : _random = random ?? Random();

  /// 演示 token 的固定 secret，只为让校验和自洽，不承担安全职责。
  static const String _tokenSecret = 'yuki-campus-mock-v1';
  static const Duration tokenTtl = Duration(days: 7);

  final CampusDbStore store;
  final Duration latency;
  final int jitterMs;
  final MockErrorInjector? injector;
  final Random _random;

  late final MockRouter _router = buildMockRouter();

  CampusDb? _db;
  Future<void>? _ready;
  Future<void>? _writeChain;
  bool _dirty = false;

  /// 最近一次落盘失败的原因（通常是 Web 端的配额超限）。
  /// 界面可以在设置页把它显示出来，而不是静默丢数据。
  Object? lastSaveError;

  @override
  String? authToken;

  @override
  void Function()? onUnauthorized;

  @override
  CampusDb get db {
    final value = _db;
    if (value == null) {
      throw StateError('MockApiClient 尚未加载，先 await ensureLoaded()');
    }
    return value;
  }

  bool get isPersistent => store.isPersistent;

  // ── 请求入口 ──────────────────────────────────────────────

  @override
  Future<Object?> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    await ensureLoaded();
    await _sleep();

    final injected = injector?.call(method, path);
    if (injected != null) {
      if (injected.status == 401 && authToken != null) onUnauthorized?.call();
      throw ApiException(injected.status, injected.code, injected.message);
    }

    final req = MockRequest(
      method: method,
      path: path,
      backend: this,
      query: query ?? const {},
      body: body,
      token: authToken,
      user: _currentUser(),
    );

    try {
      return await _router.dispatch(req);
    } on ApiException catch (e) {
      if (e.isUnauthorized && authToken != null) onUnauthorized?.call();
      rethrow;
    }
  }

  Future<void> _sleep() async {
    if (latency == Duration.zero) return;
    final extra = jitterMs <= 0 ? 0 : _random.nextInt(jitterMs + 1);
    await Future<void>.delayed(latency + Duration(milliseconds: extra));
  }

  CampusUser? _currentUser() {
    final token = authToken;
    if (token == null || token.isEmpty) return null;
    return userForToken(token);
  }

  // ── 加载 / 保存 ───────────────────────────────────────────

  Future<void> ensureLoaded() => _ready ??= _load();

  Future<void> _load() async {
    CampusDb? loaded;
    try {
      final raw = await store.load();
      if (raw != null) {
        final candidate = CampusDb.fromJson(raw);
        if (candidate.schemaVersion == CampusDb.currentSchemaVersion) {
          loaded = candidate;
        }
      }
    } catch (_) {
      // 文件损坏 / 权限异常一律当作「没有」，重新播种，页面不白屏。
      loaded = null;
    }

    _db = loaded ?? CampusSeed.build();
    if (loaded == null) {
      try {
        await store.save(_db!.toJson());
      } catch (e) {
        lastSaveError = e;
      }
    }
  }

  @override
  T mutate<T>(T Function(CampusDb db) fn) {
    final result = fn(db);
    _scheduleSave();
    return result;
  }

  void _scheduleSave() {
    _dirty = true;
    _writeChain ??= _drainWrites();
  }

  Future<void> _drainWrites() async {
    // 先让出一次，保证 _writeChain 已赋值再进入循环，避免同步完成时踩空。
    await Future<void>.value();
    try {
      while (_dirty) {
        _dirty = false;
        try {
          await store.save(db.toJson());
          lastSaveError = null;
        } catch (e) {
          // 落盘失败不炸界面：内存仍是权威副本，下一次改动会再试一次。
          lastSaveError = e;
        }
      }
    } finally {
      _writeChain = null;
    }
  }

  /// 等所有挂起的写盘完成。测试与退出前调用。
  Future<void> flush() async {
    final chain = _writeChain;
    if (chain != null) await chain;
  }

  /// 清库重播，用于「重置演示数据」。
  Future<void> resetDemoData() async {
    _db = CampusSeed.build();
    _dirty = false;
    authToken = null;
    await store.save(_db!.toJson());
  }

  // ── MockBackend ──────────────────────────────────────────

  @override
  IssuedToken issueSession(String userId) {
    final expiresAt = DateTime.now().toUtc().add(tokenTtl);
    final expMs = expiresAt.millisecondsSinceEpoch;
    final token = 'mock.v1.$userId.$expMs.${_checksumOf(userId, expMs)}';
    db.sessions[token] = {
      'userId': userId,
      'expiresAt': expiresAt.toIso8601String(),
    };
    _scheduleSave();
    return IssuedToken(token, expiresAt);
  }

  @override
  CampusUser? userForToken(String token) {
    final session = asMap(db.sessions[token]);
    if (session.isEmpty) return null;

    final parts = token.split('.');
    if (parts.length != 5) return null;
    final userId = parts[2];
    final expMs = int.tryParse(parts[3]);
    if (expMs == null) return null;
    if (parts[4] != _checksumOf(userId, expMs)) return null;
    if (DateTime.now().millisecondsSinceEpoch > expMs) return null;
    if (asString(session['userId']) != userId) return null;

    final row = db.users.where((u) => u['id'] == userId).firstOrNull;
    if (row == null) return null;
    return CampusUser.fromJson(row);
  }

  /// 登出时把 token 从会话表里摘掉。
  @override
  void revokeToken(String token) {
    if (db.sessions.remove(token) != null) _scheduleSave();
  }

  @override
  void pushMessage({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String refType,
    String? refId,
  }) {
    db.messages.add({
      'id': db.nextId('ms'),
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'refType': refType,
      'refId': refId,
      'read': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    _scheduleSave();
  }

  // ── token 校验和 ─────────────────────────────────────────

  static String _checksumOf(String userId, int expMs) {
    const fnvOffset = 0x811c9dc5;
    const fnvPrime = 0x01000193;
    final src = '$userId.$expMs.$_tokenSecret';
    var hash = fnvOffset;
    for (final code in src.codeUnits) {
      hash ^= code;
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  @override
  void dispose() {
    _dirty = false;
  }
}
