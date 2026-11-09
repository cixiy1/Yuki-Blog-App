import '../../models/campus/campus_activity.dart';
import '../../models/campus/json_utils.dart';
import '../../models/campus/paged.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

abstract interface class ActivityRepository {
  /// [filter] 取 `open` / `mine` / `joined` / `pending` / `all`。
  Future<Paged<CampusActivity>> list({
    String filter = 'open',
    String query = '',
    int page = 1,
  });

  /// 待审核队列，仅管理员。
  Future<Paged<CampusActivity>> pendingReview({int page = 1});

  Future<CampusActivity> detail(String id);

  Future<CampusActivity> create({
    required String title,
    required String description,
    required String location,
    required DateTime startAt,
    required DateTime signupDeadline,
    required int capacity,
    DateTime? endAt,
    List<String> imageIds = const [],
    bool schoolWide = false,
  });

  /// 只传要改的字段；不传的不动。组织者改过内容会退回待审核。
  Future<CampusActivity> update(
    String id, {
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? signupDeadline,
    int? capacity,
    List<String>? imageIds,
    bool? schoolWide,
  });

  Future<CampusActivity> review(
    String id, {
    required bool approve,
    String reason = '',
  });

  /// 报名。名额满了自动进候补。
  Future<CampusActivity> signup(String id);

  /// 取消报名。取消的是正式名额时，候补第一位自动递补。
  Future<CampusActivity> cancelSignup(String id);

  Future<List<ActivitySignup>> signups(String id);

  Future<CampusActivity> cancel(String id);
}

class ApiActivityRepository implements ActivityRepository {
  ApiActivityRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paged<CampusActivity>> list({
    String filter = 'open',
    String query = '',
    int page = 1,
  }) async {
    final result = await _api.get(
      ApiPaths.activities,
      query: {
        'filter': filter,
        if (query.isNotEmpty) 'q': query,
        'page': '$page',
      },
    );
    return Paged.fromJson(result, CampusActivity.fromJson);
  }

  @override
  Future<Paged<CampusActivity>> pendingReview({int page = 1}) async {
    final result = await _api.get(
      ApiPaths.activitiesPendingReview,
      query: {'page': '$page'},
    );
    return Paged.fromJson(result, CampusActivity.fromJson);
  }

  @override
  Future<CampusActivity> detail(String id) async {
    final result = await _api.get(ApiPaths.activityOne(id));
    return CampusActivity.fromJson(asMap(result));
  }

  @override
  Future<CampusActivity> create({
    required String title,
    required String description,
    required String location,
    required DateTime startAt,
    required DateTime signupDeadline,
    required int capacity,
    DateTime? endAt,
    List<String> imageIds = const [],
    bool schoolWide = false,
  }) async {
    final result = await _api.post(
      ApiPaths.activities,
      body: {
        'title': title,
        'description': description,
        'location': location,
        'startAt': startAt.toUtc().toIso8601String(),
        'signupDeadline': signupDeadline.toUtc().toIso8601String(),
        'capacity': capacity,
        'imageIds': imageIds,
        'scope': schoolWide ? 'schoolWide' : 'classOnly',
        if (endAt != null) 'endAt': endAt.toUtc().toIso8601String(),
      },
    );
    return CampusActivity.fromJson(asMap(result));
  }

  @override
  Future<CampusActivity> update(
    String id, {
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? signupDeadline,
    int? capacity,
    List<String>? imageIds,
    bool? schoolWide,
  }) async {
    final result = await _api.patch(
      ApiPaths.activityOne(id),
      body: {
        'title': ?title,
        'description': ?description,
        'location': ?location,
        'startAt': ?startAt?.toUtc().toIso8601String(),
        'endAt': ?endAt?.toUtc().toIso8601String(),
        'signupDeadline': ?signupDeadline?.toUtc().toIso8601String(),
        'capacity': ?capacity,
        'imageIds': ?imageIds,
        if (schoolWide != null)
          'scope': schoolWide ? 'schoolWide' : 'classOnly',
      },
    );
    return CampusActivity.fromJson(asMap(result));
  }

  @override
  Future<CampusActivity> review(
    String id, {
    required bool approve,
    String reason = '',
  }) async {
    final result = await _api.post(
      ApiPaths.activityReview(id),
      body: {'approve': approve, 'reason': reason},
    );
    return CampusActivity.fromJson(asMap(result));
  }

  @override
  Future<CampusActivity> signup(String id) async {
    final result = await _api.post(ApiPaths.activitySignup(id));
    return CampusActivity.fromJson(asMap(result));
  }

  @override
  Future<CampusActivity> cancelSignup(String id) async {
    final result = await _api.post(ApiPaths.activityCancelSignup(id));
    return CampusActivity.fromJson(asMap(result));
  }

  @override
  Future<List<ActivitySignup>> signups(String id) async {
    final result = await _api.get(ApiPaths.activitySignups(id));
    return Paged.fromJson(result, ActivitySignup.fromJson).items;
  }

  @override
  Future<CampusActivity> cancel(String id) async {
    final result = await _api.post(ApiPaths.activityCancel(id));
    return CampusActivity.fromJson(asMap(result));
  }
}
