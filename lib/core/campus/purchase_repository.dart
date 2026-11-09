import '../../models/campus/json_utils.dart';
import '../../models/campus/paged.dart';
import '../../models/campus/purchase_task.dart';
import '../../models/campus/review.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

/// 代买清单里的一项，提交前的草稿形态。
class PurchaseDraftItem {
  const PurchaseDraftItem({required this.name, this.qty = 1, this.note});

  final String name;
  final int qty;
  final String? note;

  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'note': note};
}

abstract interface class PurchaseRepository {
  /// [status] 取 `active` / `pending` / `finished` / `all`。
  Future<Paged<PurchaseTask>> list({
    String status = 'active',
    bool onlyMine = false,
    bool onlyCourier = false,
    int page = 1,
  });

  Future<PurchaseTask> detail(String id);

  Future<PurchaseTask> create({
    required String title,
    required String fromPlace,
    required String toPlace,
    required List<PurchaseDraftItem> items,
    required int amountCents,
    required PaymentMethod paymentMethod,
    required DateTime deadline,
    String note = '',
    bool schoolWide = false,
  });

  Future<PurchaseTask> accept(String id);

  Future<PurchaseTask> markDelivered(String id);

  Future<PurchaseTask> complete(String id);

  Future<PurchaseTask> cancel(String id);

  /// 这条任务收到的全部评价。
  Future<List<Review>> reviews(String id);

  /// 提交一条评价。同一任务同一人只能评一次，由服务端挡。
  Future<Review> submitReview(
    String id, {
    required int stars,
    List<String> tags = const [],
    String comment = '',
  });
}

class ApiPurchaseRepository implements PurchaseRepository {
  ApiPurchaseRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paged<PurchaseTask>> list({
    String status = 'active',
    bool onlyMine = false,
    bool onlyCourier = false,
    int page = 1,
  }) async {
    final result = await _api.get(
      ApiPaths.purchases,
      query: {
        'status': status,
        if (onlyMine) 'mine': '1',
        if (onlyCourier) 'courier': '1',
        'page': '$page',
      },
    );
    return Paged.fromJson(result, PurchaseTask.fromJson);
  }

  @override
  Future<PurchaseTask> detail(String id) async {
    final result = await _api.get(ApiPaths.purchaseOne(id));
    return PurchaseTask.fromJson(asMap(result));
  }

  @override
  Future<PurchaseTask> create({
    required String title,
    required String fromPlace,
    required String toPlace,
    required List<PurchaseDraftItem> items,
    required int amountCents,
    required PaymentMethod paymentMethod,
    required DateTime deadline,
    String note = '',
    bool schoolWide = false,
  }) async {
    final result = await _api.post(
      ApiPaths.purchases,
      body: {
        'title': title,
        'fromPlace': fromPlace,
        'toPlace': toPlace,
        'items': [for (final item in items) item.toJson()],
        'amountCents': amountCents,
        'paymentMethod': paymentMethod.name,
        'deadline': deadline.toUtc().toIso8601String(),
        'note': note,
        'scope': schoolWide ? 'schoolWide' : 'classOnly',
      },
    );
    return PurchaseTask.fromJson(asMap(result));
  }

  @override
  Future<PurchaseTask> accept(String id) async {
    final result = await _api.post(ApiPaths.purchaseAccept(id));
    return PurchaseTask.fromJson(asMap(result));
  }

  @override
  Future<PurchaseTask> markDelivered(String id) async {
    final result = await _api.post(ApiPaths.purchaseDeliver(id));
    return PurchaseTask.fromJson(asMap(result));
  }

  @override
  Future<PurchaseTask> complete(String id) async {
    final result = await _api.post(ApiPaths.purchaseComplete(id));
    return PurchaseTask.fromJson(asMap(result));
  }

  @override
  Future<PurchaseTask> cancel(String id) async {
    final result = await _api.post(ApiPaths.purchaseCancel(id));
    return PurchaseTask.fromJson(asMap(result));
  }

  @override
  Future<List<Review>> reviews(String id) async {
    final result = await _api.get(ApiPaths.purchaseReviews(id));
    return [
      for (final row in asMapList(asMap(result)['items']))
        Review.fromJson(row),
    ];
  }

  @override
  Future<Review> submitReview(
    String id, {
    required int stars,
    List<String> tags = const [],
    String comment = '',
  }) async {
    final result = await _api.post(
      ApiPaths.purchaseReviews(id),
      body: {
        'stars': stars,
        'tags': tags,
        'comment': comment,
      },
    );
    return Review.fromJson(asMap(result));
  }
}
