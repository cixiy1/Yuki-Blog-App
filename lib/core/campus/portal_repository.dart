import '../../models/campus/express_task.dart';
import '../../models/campus/json_utils.dart';
import '../../models/campus/lost_found_post.dart';
import '../../models/campus/market_item.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

/// 门户首页需要的全部数据，一次请求拿齐。
class PortalSummary {
  const PortalSummary({
    required this.counts,
    required this.unread,
    required this.latestLostFound,
    required this.latestMarket,
    required this.pendingExpress,
  });

  const PortalSummary.empty()
      : counts = const {},
        unread = 0,
        latestLostFound = const [],
        latestMarket = const [],
        pendingExpress = const [];

  /// 六个模块的角标数字：lostFound / market / express /
  /// activityPendingReview / forms / purchase。
  final Map<String, int> counts;
  final int unread;
  final List<LostFoundPost> latestLostFound;
  final List<MarketItem> latestMarket;
  final List<ExpressTask> pendingExpress;

  int countOf(String key) => counts[key] ?? 0;

  factory PortalSummary.fromJson(Object? json) {
    final map = asMap(json);
    final rawCounts = asMap(map['counts']);
    return PortalSummary(
      counts: {
        for (final e in rawCounts.entries) e.key: asInt(e.value),
      },
      unread: asInt(map['unread']),
      latestLostFound: [
        for (final row in asMapList(map['latestLostFound']))
          LostFoundPost.fromJson(row),
      ],
      latestMarket: [
        for (final row in asMapList(map['latestMarket']))
          MarketItem.fromJson(row),
      ],
      pendingExpress: [
        for (final row in asMapList(map['pendingExpress']))
          ExpressTask.fromJson(row),
      ],
    );
  }
}

abstract interface class PortalRepository {
  Future<PortalSummary> summary();
}

class ApiPortalRepository implements PortalRepository {
  ApiPortalRepository(this._api);

  final ApiClient _api;

  @override
  Future<PortalSummary> summary() async {
    final result = await _api.get(ApiPaths.portalSummary);
    return PortalSummary.fromJson(result);
  }
}
