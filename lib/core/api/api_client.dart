import '../../models/campus/json_utils.dart';

/// 后端返回的业务错误。
///
/// 与真 HTTP 后端约定一致：`{"error":{"code","message","fieldErrors":{}}}`。
/// Mock 层直接抛同一个类型，所以业务代码不需要区分「真后端」还是「假后端」。
class ApiException implements Exception {
  const ApiException(
    this.statusCode,
    this.code,
    this.message, {
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String code;
  final String message;

  /// 字段级校验错误：key 是字段名（表单是 fieldId）。
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 422;

  /// 从响应体里尽力剥出错误信息；剥不出就用状态码兜底。
  factory ApiException.fromPayload(int statusCode, Object? payload) {
    final map = asMap(payload);
    final err = asMap(map['error']);
    final rawFields = asMap(err['fieldErrors']);
    return ApiException(
      statusCode,
      asString(err['code'], _codeForStatus(statusCode)),
      asString(err['message'], _messageForStatus(statusCode)),
      fieldErrors: {
        for (final e in rawFields.entries) e.key: asString(e.value),
      },
    );
  }

  static String _codeForStatus(int status) => switch (status) {
        400 => 'BAD_REQUEST',
        401 => 'UNAUTHORIZED',
        403 => 'FORBIDDEN',
        404 => 'NOT_FOUND',
        409 => 'CONFLICT',
        413 => 'STORAGE_FULL',
        422 => 'VALIDATION_FAILED',
        _ => 'INTERNAL',
      };

  static String _messageForStatus(int status) => switch (status) {
        400 => '请求有误',
        401 => '登录已过期，请重新登录',
        403 => '没有权限执行该操作',
        404 => '内容不存在',
        409 => '状态冲突，请刷新后重试',
        413 => '本地存储空间不足',
        422 => '提交内容校验未通过',
        _ => '服务异常，请稍后重试',
      };

  @override
  String toString() => 'ApiException($statusCode $code): $message';
}

/// 唯一的网络出口抽象。
///
/// 业务 repository 只依赖这个接口，因此「本地 Mock」与「真后端」可以整块替换。
abstract interface class ApiClient {
  /// 每次请求自动附带的 Bearer token；null 表示未登录。
  String? get authToken;
  set authToken(String? value);

  /// 收到 401 时回调，用于把登录态标记为过期并跳登录页。
  void Function()? get onUnauthorized;
  set onUnauthorized(void Function()? callback);

  /// 发一个请求。成功返回解析后的 JSON（`Map` / `List` / `null`）；
  /// 失败抛 [ApiException]。
  Future<Object?> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  });

  void dispose();
}

/// 让调用点短一点：`api.get(path)` / `api.post(path, body: {...})`。
extension ApiClientX on ApiClient {
  Future<Object?> get(String path, {Map<String, String>? query}) =>
      request('GET', path, query: query);

  Future<Object?> post(String path, {Object? body}) =>
      request('POST', path, body: body as Map<String, dynamic>?);

  Future<Object?> put(String path, {Object? body}) =>
      request('PUT', path, body: body as Map<String, dynamic>?);

  Future<Object?> patch(String path, {Object? body}) =>
      request('PATCH', path, body: body as Map<String, dynamic>?);

  Future<Object?> delete(String path) => request('DELETE', path);
}
