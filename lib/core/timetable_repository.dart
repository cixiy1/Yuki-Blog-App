import 'package:yuki_blog_app/models/timetable.dart';

/// 动态课表数据源接口。
///
/// **页面只依赖这个接口拿数据**，不关心数据来自哪里：
/// - 当前默认实现：[AssetTimetableRepository]（读取打包进 App 的 JSON）
/// - 后续接网络时，只需新增一个实现类（如从
///   `https://yiyu14.top/assets/data/schedule-2615.json` 拉取），
///   在 `SchedulePage(repository: ...)` 处替换即可，UI 与解析逻辑零改动。
///
/// ```dart
/// final class NetworkTimetableRepository implements TimetableRepository {
///   const NetworkTimetableRepository(this._client);
///   final http.Client _client;
///
///   @override
///   Future<TimetableData> loadTimetable() async {
///     final resp = await _client.get(Uri.parse(_url));
///     return TimetableData.fromRawJson(utf8.decode(resp.bodyBytes));
///   }
/// }
/// ```
abstract interface class TimetableRepository {
  /// 加载课表全量数据（meta + courses + overrides + notices）。
  Future<TimetableData> loadTimetable();
}
