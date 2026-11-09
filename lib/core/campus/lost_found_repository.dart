import '../../models/campus/json_utils.dart';
import '../../models/campus/lost_found_post.dart';
import '../../models/campus/paged.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

abstract interface class LostFoundRepository {
  Future<Paged<LostFoundPost>> list({
    LostFoundType? type,
    String location = '',
    int? days,
    String query = '',
    int page = 1,
  });

  Future<LostFoundPost> detail(String id);

  Future<LostFoundPost> create({
    required LostFoundType type,
    required String title,
    required String description,
    required String location,
    required String contact,
    required DateTime occurredAt,
    List<String> imageIds = const [],
  });

  Future<LostFoundPost> update(
    String id, {
    String? title,
    String? description,
    String? location,
    String? contact,
    DateTime? occurredAt,
    List<String>? imageIds,
  });

  Future<LostFoundPost> close(String id);

  Future<void> remove(String id);
}

class ApiLostFoundRepository implements LostFoundRepository {
  ApiLostFoundRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paged<LostFoundPost>> list({
    LostFoundType? type,
    String location = '',
    int? days,
    String query = '',
    int page = 1,
  }) async {
    final result = await _api.get(
      ApiPaths.lostFound,
      query: {
        'status': 'open',
        if (type != null) 'type': type.name,
        if (location.trim().isNotEmpty) 'location': location.trim(),
        if (days != null && days > 0) 'days': '$days',
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'page': '$page',
      },
    );
    return Paged.fromJson(result, LostFoundPost.fromJson);
  }

  @override
  Future<LostFoundPost> detail(String id) async {
    final result = await _api.get(ApiPaths.lostFoundOne(id));
    return LostFoundPost.fromJson(asMap(result));
  }

  @override
  Future<LostFoundPost> create({
    required LostFoundType type,
    required String title,
    required String description,
    required String location,
    required String contact,
    required DateTime occurredAt,
    List<String> imageIds = const [],
  }) async {
    final result = await _api.post(
      ApiPaths.lostFound,
      body: {
        'type': type.name,
        'title': title,
        'description': description,
        'location': location,
        'contact': contact,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'imageIds': imageIds,
      },
    );
    return LostFoundPost.fromJson(asMap(result));
  }

  @override
  Future<LostFoundPost> update(
    String id, {
    String? title,
    String? description,
    String? location,
    String? contact,
    DateTime? occurredAt,
    List<String>? imageIds,
  }) async {
    final result = await _api.patch(
      ApiPaths.lostFoundOne(id),
      body: {
        'title': ?title,
        'description': ?description,
        'location': ?location,
        'contact': ?contact,
        if (occurredAt != null)
          'occurredAt': occurredAt.toUtc().toIso8601String(),
        'imageIds': ?imageIds,
      },
    );
    return LostFoundPost.fromJson(asMap(result));
  }

  @override
  Future<LostFoundPost> close(String id) async {
    final result = await _api.post(ApiPaths.lostFoundClose(id));
    return LostFoundPost.fromJson(asMap(result));
  }

  @override
  Future<void> remove(String id) async {
    await _api.delete(ApiPaths.lostFoundOne(id));
  }
}
