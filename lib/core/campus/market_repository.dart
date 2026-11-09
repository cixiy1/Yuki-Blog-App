import '../../models/campus/json_utils.dart';
import '../../models/campus/market_item.dart';
import '../../models/campus/paged.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

abstract interface class MarketRepository {
  Future<Paged<MarketItem>> list({
    MarketCategory? category,
    MarketSort sort = MarketSort.latest,
    String query = '',
    bool onlyMine = false,
    int page = 1,
  });

  Future<MarketItem> detail(String id);

  Future<MarketItem> create({
    required String title,
    required String description,
    required String contact,
    required int priceCents,
    required ItemCondition condition,
    required MarketCategory category,
    List<String> imageIds = const [],
  });

  Future<MarketItem> update(
    String id, {
    String? title,
    String? description,
    String? contact,
    int? priceCents,
    ItemCondition? condition,
    MarketCategory? category,
    List<String>? imageIds,
  });

  Future<MarketItem> markSold(String id);

  Future<void> remove(String id);
}

class ApiMarketRepository implements MarketRepository {
  ApiMarketRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paged<MarketItem>> list({
    MarketCategory? category,
    MarketSort sort = MarketSort.latest,
    String query = '',
    bool onlyMine = false,
    int page = 1,
  }) async {
    final result = await _api.get(
      ApiPaths.market,
      query: {
        if (category != null) 'category': category.name,
        'sort': switch (sort) {
          MarketSort.latest => 'latest',
          MarketSort.priceAsc => 'priceAsc',
          MarketSort.priceDesc => 'priceDesc',
        },
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (onlyMine) 'mine': '1',
        'page': '$page',
      },
    );
    return Paged.fromJson(result, MarketItem.fromJson);
  }

  @override
  Future<MarketItem> detail(String id) async {
    final result = await _api.get(ApiPaths.marketOne(id));
    return MarketItem.fromJson(asMap(result));
  }

  @override
  Future<MarketItem> create({
    required String title,
    required String description,
    required String contact,
    required int priceCents,
    required ItemCondition condition,
    required MarketCategory category,
    List<String> imageIds = const [],
  }) async {
    final result = await _api.post(
      ApiPaths.market,
      body: {
        'title': title,
        'description': description,
        'contact': contact,
        'priceCents': priceCents,
        'condition': condition.name,
        'category': category.name,
        'imageIds': imageIds,
      },
    );
    return MarketItem.fromJson(asMap(result));
  }

  @override
  Future<MarketItem> update(
    String id, {
    String? title,
    String? description,
    String? contact,
    int? priceCents,
    ItemCondition? condition,
    MarketCategory? category,
    List<String>? imageIds,
  }) async {
    final result = await _api.patch(
      ApiPaths.marketOne(id),
      body: {
        'title': ?title,
        'description': ?description,
        'contact': ?contact,
        'priceCents': ?priceCents,
        if (condition != null) 'condition': condition.name,
        if (category != null) 'category': category.name,
        'imageIds': ?imageIds,
      },
    );
    return MarketItem.fromJson(asMap(result));
  }

  @override
  Future<MarketItem> markSold(String id) async {
    final result = await _api.post(ApiPaths.marketSold(id));
    return MarketItem.fromJson(asMap(result));
  }

  @override
  Future<void> remove(String id) async {
    await _api.delete(ApiPaths.marketOne(id));
  }
}
