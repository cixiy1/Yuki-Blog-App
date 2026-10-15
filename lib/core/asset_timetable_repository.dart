import 'package:flutter/services.dart' show rootBundle;
import 'package:yuki_blog_app/core/timetable_repository.dart';
import 'package:yuki_blog_app/models/timetable.dart';

/// 本地资源数据源：读取打包进 App 的 `assets/data/schedule-2615.json`。
///
/// 数据与博客线（yiyu14.top）保持同源同格式，更新课表时
/// 同步替换这个 JSON 即可，无需改任何代码。
class AssetTimetableRepository implements TimetableRepository {
  const AssetTimetableRepository({
    this.assetPath = 'assets/data/schedule-2615.json',
  });

  final String assetPath;

  @override
  Future<TimetableData> loadTimetable() async {
    final raw = await rootBundle.loadString(assetPath);
    return raw.decodeTimetable();
  }
}

/// 供测试 / debug 使用的内存数据源。
class InMemoryTimetableRepository implements TimetableRepository {
  const InMemoryTimetableRepository(this._data);

  factory InMemoryTimetableRepository.fromRawJson(String raw) =>
      InMemoryTimetableRepository(TimetableData.fromRawJson(raw));

  final TimetableData _data;

  @override
  Future<TimetableData> loadTimetable() async => _data;
}

/// JSON 解码失败时抛出，便于页面展示错误态。
class TimetableParseException implements Exception {
  const TimetableParseException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'TimetableParseException: $message';
}

/// 把 [AssetTimetableRepository] 的字符串加载包一层统一异常（可选增强）。
extension TimetableRepositoryJson on String {
  TimetableData decodeTimetable() {
    try {
      return TimetableData.fromRawJson(this);
    } on FormatException catch (e) {
      throw TimetableParseException('课表数据解析失败', e);
    }
  }
}
