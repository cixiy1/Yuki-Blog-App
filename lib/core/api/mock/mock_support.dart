import '../../../models/campus/campus_user.dart';
import '../api_client.dart';
import 'mock_request.dart';

/// Mock handler 共用的一组断言与读取工具。
///
/// 服务端是唯一可信的权限边界：客户端隐藏按钮只是为了好看，
/// 真正的 403 从这里出。

Never badRequest(String message) =>
    throw ApiException(400, 'BAD_REQUEST', message);

Never unauthorized([String message = '请先登录']) =>
    throw ApiException(401, 'UNAUTHORIZED', message);

Never forbidden([String message = '没有权限执行该操作']) =>
    throw ApiException(403, 'FORBIDDEN', message);

Never notFound([String message = '内容不存在']) =>
    throw ApiException(404, 'NOT_FOUND', message);

Never conflict(String code, String message) =>
    throw ApiException(409, code, message);

Never invalid(Map<String, String> fieldErrors, [String message = '提交内容校验未通过']) =>
    throw ApiException(422, 'VALIDATION_FAILED', message,
        fieldErrors: fieldErrors);

/// 必须登录。
CampusUser requireUser(MockRequest req) {
  final user = req.user;
  if (user == null) unauthorized();
  return user;
}

/// 必须至少是某档角色。
CampusUser requireRole(MockRequest req, {UserRole min = UserRole.committeeman}) {
  final user = requireUser(req);
  if (min == UserRole.admin && user.role != UserRole.admin) {
    forbidden('仅管理员可执行该操作');
  }
  if (min == UserRole.committeeman && user.role == UserRole.student) {
    forbidden('仅班委或管理员可执行该操作');
  }
  return user;
}

/// 按 id 找行，找不到抛 404。
Map<String, dynamic> findRow(
  List<Map<String, dynamic>> rows,
  String? id, {
  String what = '内容',
}) {
  if (id == null || id.isEmpty) notFound('$what不存在');
  for (final row in rows) {
    if (row['id'] == id) return row;
  }
  notFound('$what不存在');
}

/// 按 id 找行，找不到返回 null。
Map<String, dynamic>? tryFindRow(
  List<Map<String, dynamic>> rows,
  String? id,
) {
  if (id == null) return null;
  for (final row in rows) {
    if (row['id'] == id) return row;
  }
  return null;
}

/// 读必填字符串并裁剪空白。
String requiredString(
  Map<String, dynamic> json,
  String key, {
  String label = '内容',
  int maxLength = 500,
}) {
  final raw = json[key];
  final value = raw is String ? raw.trim() : '';
  if (value.isEmpty) invalid({key: '$label不能为空'});
  if (value.length > maxLength) invalid({key: '$label最多 $maxLength 字'});
  return value;
}

String optionalString(Map<String, dynamic> json, String key, {int maxLength = 2000}) {
  final raw = json[key];
  if (raw is! String) return '';
  final value = raw.trim();
  return value.length > maxLength ? value.substring(0, maxLength) : value;
}

int requiredInt(
  Map<String, dynamic> json,
  String key, {
  String label = '数值',
  int? min,
  int? max,
}) {
  final raw = json[key];
  final value = raw is num ? raw.toInt() : int.tryParse('$raw');
  if (value == null) invalid({key: '$label必须是整数'});
  if (min != null && value < min) invalid({key: '$label不能小于 $min'});
  if (max != null && value > max) invalid({key: '$label不能大于 $max'});
  return value;
}

DateTime requiredDate(
  Map<String, dynamic> json,
  String key, {
  String label = '时间',
}) {
  final raw = json[key];
  final value = raw is DateTime ? raw : DateTime.tryParse('$raw');
  if (value == null) invalid({key: '$label格式不正确'});
  return value;
}

DateTime? optionalDate(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null || raw == '') return null;
  return raw is DateTime ? raw : DateTime.tryParse('$raw');
}

List<String> stringList(Map<String, dynamic> json, String key, {int maxItems = 3}) {
  final raw = json[key];
  if (raw is! List) return const [];
  final list = [
    for (final e in raw)
      if (e is String && e.isNotEmpty) e,
  ];
  if (list.length > maxItems) invalid({key: '$key最多 $maxItems 项'});
  return list;
}

/// 字符串分页参数。
int pageParam(MockRequest req) {
  final raw = int.tryParse(req.query['page'] ?? '') ?? 1;
  return raw < 1 ? 1 : raw;
}

int pageSizeParam(MockRequest req) {
  final raw = int.tryParse(req.query['pageSize'] ?? '') ?? 20;
  if (raw < 1) return 1;
  return raw > 50 ? 50 : raw;
}

/// 切一页，返回标准分页响应。
Map<String, dynamic> paginate<T>(
  List<T> all,
  int page,
  int pageSize,
) {
  final start = (page - 1) * pageSize;
  final items = start >= all.length
      ? <T>[]
      : all.sublist(start, (start + pageSize).clamp(0, all.length));
  return {
    'items': items,
    'total': all.length,
    'page': page,
    'pageSize': pageSize,
  };
}
