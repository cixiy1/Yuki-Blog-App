import 'json_utils.dart';

/// 分页响应载体。与后端的 `{items,total,page,pageSize}` 一一对应。
class Paged<T> {
  const Paged({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  const Paged.empty()
      : items = const [],
        total = 0,
        page = 1,
        pageSize = 20;

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  /// 解析分页响应；[parse] 负责把单条 JSON 转成 [T]。
  factory Paged.fromJson(
    Object? json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final map = asMap(json);
    return Paged<T>(
      items: [
        for (final row in asMapList(map['items'])) parse(row),
      ],
      total: asInt(map['total'], asMapList(map['items']).length),
      page: asInt(map['page'], 1),
      pageSize: asInt(map['pageSize'], 20),
    );
  }
}
