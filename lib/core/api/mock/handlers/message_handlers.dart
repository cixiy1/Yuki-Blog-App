import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';

void registerMessageHandlers(MockRouter r) {
  r.on('GET', ApiPaths.messages, _list);
  r.on('GET', ApiPaths.messagesUnreadCount, _unreadCount);
  r.on('POST', ApiPaths.messagesReadAll, _readAll);
  r.on('POST', '/messages/:id/read', _readOne);
}

int _countUnread(MockRequest req, String uid) => req.backend.db.messages
    .where((m) => m['userId'] == uid && m['read'] != true)
    .length;

/// 只返回属于当前用户的消息——别人被接单的消息不该出现在你的收件箱。
List<Map<String, dynamic>> _mine(MockRequest req, String uid) => [
      for (final m in req.backend.db.messages)
        if (m['userId'] == uid) m,
    ]..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));

Object? _list(MockRequest req) {
  final user = requireUser(req);
  final unreadOnly = req.query['unreadOnly'] == 'true';

  final rows = [
    for (final m in _mine(req, user.id))
      if (!unreadOnly || m['read'] != true) m,
  ];

  return paginate(rows, pageParam(req), pageSizeParam(req));
}

Object? _unreadCount(MockRequest req) {
  final user = requireUser(req);
  return {'count': _countUnread(req, user.id)};
}

Object? _readOne(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');

  return req.backend.mutate((db) {
    final row = findRow(db.messages, id, what: '消息');
    if (row['userId'] != user.id) forbidden('无权操作他人的消息');
    row['read'] = true;
    return {'count': _countUnread(req, user.id)};
  });
}

Object? _readAll(MockRequest req) {
  final user = requireUser(req);
  req.backend.mutate((db) {
    for (final m in db.messages) {
      if (m['userId'] == user.id) m['read'] = true;
    }
    return null;
  });
  return {'count': 0};
}
