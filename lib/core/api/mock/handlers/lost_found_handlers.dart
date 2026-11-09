import '../../../../models/campus/campus_user.dart';
import '../../../campus/permissions.dart';
import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';
import 'view_mappers.dart';

void registerLostFoundHandlers(MockRouter r) {
  r.on('GET', ApiPaths.lostFound, _list);
  r.on('POST', ApiPaths.lostFound, _create);
  r.on('GET', '/lost-found/:id', _detail);
  r.on('PATCH', '/lost-found/:id', _update);
  r.on('POST', '/lost-found/:id/close', _close);
  r.on('DELETE', '/lost-found/:id', _delete);
}

Object? _list(MockRequest req) {
  final user = requireUser(req);
  final uid = user.id;

  var rows = [
    for (final row in req.backend.db.lostFound)
      if (row['status'] != 'deleted') row,
  ];

  final status = req.query['status'];
  if (status != null && status.isNotEmpty && status != 'all') {
    rows = [
      for (final row in rows)
        if (row['status'] == status) row,
    ];
  }

  final type = req.query['type'];
  if (type != null && type.isNotEmpty) {
    rows = [
      for (final row in rows)
        if (row['type'] == type) row,
    ];
  }

  final location = req.query['location'];
  if (location != null && location.trim().isNotEmpty) {
    final needle = location.trim();
    rows = [
      for (final row in rows)
        if ('${row['location']}'.contains(needle)) row,
    ];
  }

  final days = int.tryParse(req.query['days'] ?? '');
  if (days != null && days > 0) {
    final from = DateTime.now().toUtc().subtract(Duration(days: days));
    rows = [
      for (final row in rows)
        if (_parse(row['occurredAt'])?.isAfter(from) ?? true) row,
    ];
  }

  final q = req.query['q'];
  if (q != null && q.trim().isNotEmpty) {
    final needle = q.trim().toLowerCase();
    rows = [
      for (final row in rows)
        if ('${row['title']}'.toLowerCase().contains(needle) ||
            '${row['description']}'.toLowerCase().contains(needle))
          row,
    ];
  }

  rows.sort(byNewest);

  final view = [
    for (final row in rows) lostFoundView(row, uid),
  ];
  return paginate(view, pageParam(req), pageSizeParam(req));
}

Object? _create(MockRequest req) {
  final user = requireUser(req);
  final body = req.json;

  final type = requiredString(body, 'type', label: '类型', maxLength: 8);
  if (type != 'lost' && type != 'found') {
    invalid({'type': '类型只能是 lost 或 found'});
  }

  final title = requiredString(body, 'title', label: '标题', maxLength: 40);
  final description =
      requiredString(body, 'description', label: '描述', maxLength: 500);
  final location =
      requiredString(body, 'location', label: '地点', maxLength: 40);
  final contact = requiredString(body, 'contact', label: '联系方式', maxLength: 60);
  final occurredAt = requiredDate(body, 'occurredAt', label: '发生时间');
  final imageIds = stringList(body, 'imageIds');

  return req.backend.mutate((db) {
    final id = db.nextId('lf');
    final row = <String, dynamic>{
      'id': id,
      'type': type,
      'title': title,
      'description': description,
      'location': location,
      'contact': contact,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'imageIds': imageIds,
      'authorId': user.id,
      'authorName': user.name,
      'authorClassName': user.className,
      'status': 'open',
    };
    db.lostFound.add(row);
    return lostFoundView(row, user.id);
  });
}

Object? _detail(MockRequest req) {
  final user = requireUser(req);
  final row = findRow(req.backend.db.lostFound, req.param('id'), what: '帖子');
  if (row['status'] == 'deleted') notFound('帖子已被删除');
  return lostFoundView(row, user.id);
}

Object? _update(MockRequest req) {
  final user = requireUser(req);
  final body = req.json;

  return req.backend.mutate((db) {
    final row = findRow(db.lostFound, req.param('id'), what: '帖子');
    _requireOwnerOrAdmin(row['authorId'], user, '只能编辑自己发布的帖子');

    if (body.containsKey('title')) {
      row['title'] = requiredString(body, 'title', label: '标题', maxLength: 40);
    }
    if (body.containsKey('description')) {
      row['description'] =
          requiredString(body, 'description', label: '描述', maxLength: 500);
    }
    if (body.containsKey('location')) {
      row['location'] =
          requiredString(body, 'location', label: '地点', maxLength: 40);
    }
    if (body.containsKey('contact')) {
      row['contact'] =
          requiredString(body, 'contact', label: '联系方式', maxLength: 60);
    }
    if (body.containsKey('occurredAt')) {
      row['occurredAt'] =
          requiredDate(body, 'occurredAt', label: '发生时间')
              .toUtc()
              .toIso8601String();
    }
    if (body.containsKey('imageIds')) {
      row['imageIds'] = stringList(body, 'imageIds');
    }

    return lostFoundView(row, user.id);
  });
}

Object? _close(MockRequest req) {
  final user = requireUser(req);
  return req.backend.mutate((db) {
    final row = findRow(db.lostFound, req.param('id'), what: '帖子');
    _requireOwnerOrAdmin(row['authorId'], user, '只能关闭自己发布的帖子');
    row['status'] = 'closed';
    return lostFoundView(row, user.id);
  });
}

Object? _delete(MockRequest req) {
  final user = requireUser(req);
  return req.backend.mutate((db) {
    final row = findRow(db.lostFound, req.param('id'), what: '帖子');
    _requireOwnerOrAdmin(row['authorId'], user, '只能删除自己发布的帖子');
    row['status'] = 'deleted';
    return {'ok': true};
  });
}

void _requireOwnerOrAdmin(Object? ownerId, CampusUser user, String message) {
  if (ownerId == user.id) return;
  if (can(user.role, Capability.deleteAnyPost)) return;
  forbidden(message);
}

DateTime? _parse(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;
