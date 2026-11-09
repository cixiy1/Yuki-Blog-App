import '../../models/campus/app_message.dart';
import '../../models/campus/json_utils.dart';
import '../../models/campus/paged.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

abstract interface class MessageRepository {
  Future<Paged<AppMessage>> list({bool unreadOnly = false, int page = 1});

  Future<int> unreadCount();

  /// 标记单条已读，返回新的未读数。
  Future<int> markRead(String id);

  Future<void> markAllRead();
}

class ApiMessageRepository implements MessageRepository {
  ApiMessageRepository(this._api);

  final ApiClient _api;

  @override
  Future<Paged<AppMessage>> list({bool unreadOnly = false, int page = 1}) async {
    final result = await _api.get(
      ApiPaths.messages,
      query: {
        if (unreadOnly) 'unreadOnly': 'true',
        'page': '$page',
      },
    );
    return Paged.fromJson(result, AppMessage.fromJson);
  }

  @override
  Future<int> unreadCount() async {
    final result = await _api.get(ApiPaths.messagesUnreadCount);
    return asInt(asMap(result)['count']);
  }

  @override
  Future<int> markRead(String id) async {
    final result = await _api.post(ApiPaths.messageRead(id));
    return asInt(asMap(result)['count']);
  }

  @override
  Future<void> markAllRead() async {
    await _api.post(ApiPaths.messagesReadAll);
  }
}
