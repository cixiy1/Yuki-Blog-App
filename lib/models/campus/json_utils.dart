/// 校园服务模块共用的 JSON 解析小工具。
///
/// 后端将来换成真 HTTP 后，字段缺失 / 类型不符的情况只会更多，
/// 这里统一做防御式读取，避免每个模型写一遍 `as` 转换后到处崩。
library;

/// 按枚举 `name` 反查，找不到就用 [fallback]。
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

String asString(Object? v, [String fallback = '']) => v is String ? v : fallback;

String? asStringOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

int asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double asDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

num asNum(Object? v, [num fallback = 0]) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v) ?? fallback;
  return fallback;
}

bool asBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

DateTime? asDate(Object? v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

List<String> asStringList(Object? v) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is String && e.isNotEmpty) e,
  ];
}

Map<String, dynamic> asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return {
      for (final e in v.entries) '${e.key}': e.value,
    };
  }
  return const {};
}

List<Map<String, dynamic>> asMapList(Object? v) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is Map) asMap(e),
  ];
}

/// 写 JSON 用：一律转 UTC 的 ISO8601 字符串。
String? iso(DateTime? d) => d?.toUtc().toIso8601String();
