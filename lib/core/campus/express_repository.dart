import '../../models/campus/express_task.dart';
import '../../models/campus/json_utils.dart';
import '../../models/campus/paged.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

abstract interface class ExpressRepository {
  /// [status] 取 `active` / `pending` / `finished` / `all`。
  Future<Paged<ExpressTask>> list({
    String status = 'active',
    bool onlyMine = false,
    bool onlyCourier = false,
    int page = 1,
  });

  Future<ExpressTask> detail(String id);

  Future<ExpressTask> create({
    required String station,
    required String pickupCode,
    required String deliverTo,
    required int rewardCents,
    required DateTime deadline,
    String note = '',
    bool schoolWide = false,
  });

  Future<ExpressTask> accept(String id);

  Future<ExpressTask> markDelivered(String id);

  Future<ExpressTask> complete(String id);

  Future<ExpressTask> cancel(String id);
}

class ApiExpressRepository implements ExpressRepository {
  ApiExpressRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paged<ExpressTask>> list({
    String status = 'active',
    bool onlyMine = false,
    bool onlyCourier = false,
    int page = 1,
  }) async {
    final result = await _api.get(
      ApiPaths.express,
      query: {
        'status': status,
        if (onlyMine) 'mine': '1',
        if (onlyCourier) 'courier': '1',
        'page': '$page',
      },
    );
    return Paged.fromJson(result, ExpressTask.fromJson);
  }

  @override
  Future<ExpressTask> detail(String id) async {
    final result = await _api.get(ApiPaths.expressOne(id));
    return ExpressTask.fromJson(asMap(result));
  }

  @override
  Future<ExpressTask> create({
    required String station,
    required String pickupCode,
    required String deliverTo,
    required int rewardCents,
    required DateTime deadline,
    String note = '',
    bool schoolWide = false,
  }) async {
    final result = await _api.post(
      ApiPaths.express,
      body: {
        'station': station,
        'pickupCode': pickupCode,
        'deliverTo': deliverTo,
        'rewardCents': rewardCents,
        'deadline': deadline.toUtc().toIso8601String(),
        'note': note,
        'scope': schoolWide ? 'schoolWide' : 'classOnly',
      },
    );
    return ExpressTask.fromJson(asMap(result));
  }

  @override
  Future<ExpressTask> accept(String id) async {
    final result = await _api.post(ApiPaths.expressAccept(id));
    return ExpressTask.fromJson(asMap(result));
  }

  @override
  Future<ExpressTask> markDelivered(String id) async {
    final result = await _api.post(ApiPaths.expressDeliver(id));
    return ExpressTask.fromJson(asMap(result));
  }

  @override
  Future<ExpressTask> complete(String id) async {
    final result = await _api.post(ApiPaths.expressComplete(id));
    return ExpressTask.fromJson(asMap(result));
  }

  @override
  Future<ExpressTask> cancel(String id) async {
    final result = await _api.post(ApiPaths.expressCancel(id));
    return ExpressTask.fromJson(asMap(result));
  }
}
