import 'dart:async';

import '../../../models/campus/campus_user.dart';
import 'mock_db.dart';

/// Mock 后端对 handler 暴露的能力。刻意不暴露 `MockApiClient` 本身，
/// 免得 handler 与传输层互相 import 成环。
abstract interface class MockBackend {
  CampusDb get db;

  /// 同步改内存 → 标脏 → 串行落盘。**闭包内严禁 await**，
  /// 这是「不超卖、不丢消息」的前提。
  T mutate<T>(T Function(CampusDb db) fn);

  /// 给某个用户签一个假 token，并登记进 sessions 表。
  IssuedToken issueSession(String userId);

  /// 登出时把 token 从会话表里摘掉。
  void revokeToken(String token);

  /// 从 token 反查用户；token 无效 / 过期返回 null。
  CampusUser? userForToken(String token);

  /// 给某用户投递一条消息。
  void pushMessage({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String refType,
    String? refId,
  });
}

/// 一次 Mock 请求的上下文。
class MockRequest {
  const MockRequest({
    required this.method,
    required this.path,
    required this.backend,
    this.query = const {},
    this.body,
    this.user,
    this.token,
    this.pathParams = const {},
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, dynamic>? body;
  final CampusUser? user;

  /// 本次请求携带的原始 token，登出时用来吊销。
  final String? token;
  final Map<String, String> pathParams;
  final MockBackend backend;

  /// 请求体；GET 时为 `{}`，省掉 handler 里到处判空。
  Map<String, dynamic> get json => body ?? const {};

  String? param(String key) => pathParams[key];

  MockRequest withParams(Map<String, String> params) => MockRequest(
        method: method,
        path: path,
        backend: backend,
        query: query,
        body: body,
        user: user,
        token: token,
        pathParams: params,
      );

  MockRequest withUser(CampusUser? value) => MockRequest(
        method: method,
        path: path,
        backend: backend,
        query: query,
        body: body,
        user: value,
        token: token,
        pathParams: pathParams,
      );
}

/// 新签发的会话。
class IssuedToken {
  const IssuedToken(this.token, this.expiresAt);

  final String token;
  final DateTime expiresAt;
}

typedef MockHandler = FutureOr<Object?> Function(MockRequest req);

/// 定向故障注入用。测试里让它返回 500 / 401 模拟服务异常。
class MockError {
  const MockError(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;
}

typedef MockErrorInjector = MockError? Function(String method, String path);
