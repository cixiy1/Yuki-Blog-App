import '../../../../models/campus/campus_user.dart';
import '../../../campus/permissions.dart';
import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';
import 'view_mappers.dart';

void registerMarketHandlers(MockRouter r) {
  r.on('GET', ApiPaths.market, _list);
  r.on('POST', ApiPaths.market, _create);
  r.on('GET', '/market/:id', _detail);
  r.on('PATCH', '/market/:id', _update);
  r.on('POST', '/market/:id/sold', _sold);
  r.on('DELETE', '/market/:id', _delete);
}

/// 单价的合理区间：0 元到 10 万元。低于 0 是算错，高于上限大概是手滑。
const int _maxPriceCents = 10000000;

Object? _list(MockRequest req) {
  final user = requireUser(req);
  final uid = user.id;

  var rows = [
    for (final row in req.backend.db.market)
      if (row['status'] != 'deleted') row,
  ];

  // 默认只看在售；`status=all` 才把已售出的一起给（个人主页用）。
  final status = req.query['status'];
  if (status == null || status.isEmpty) {
    rows = [
      for (final row in rows)
        if (row['status'] == 'onSale') row,
    ];
  } else if (status != 'all') {
    rows = [
      for (final row in rows)
        if (row['status'] == status) row,
    ];
  }

  final category = req.query['category'];
  if (category != null && category.isNotEmpty) {
    rows = [
      for (final row in rows)
        if (row['category'] == category) row,
    ];
  }

  final mine = req.query['mine'];
  if (mine == '1') {
    rows = [
      for (final row in rows)
        if (row['sellerId'] == uid) row,
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

  final sort = req.query['sort'] ?? 'latest';
  rows.sort((a, b) {
    switch (sort) {
      case 'priceAsc':
        return _price(a).compareTo(_price(b));
      case 'priceDesc':
        return _price(b).compareTo(_price(a));
      default:
        return byNewest(a, b);
    }
  });

  return paginate(
    [for (final row in rows) marketView(row, uid)],
    pageParam(req),
    pageSizeParam(req),
  );
}

Object? _create(MockRequest req) {
  final user = requireUser(req);
  final body = req.json;

  final title = requiredString(body, 'title', label: '标题', maxLength: 40);
  final description =
      requiredString(body, 'description', label: '描述', maxLength: 500);
  final contact = requiredString(body, 'contact', label: '联系方式', maxLength: 60);
  final priceCents = requiredInt(body, 'priceCents',
      label: '价格', min: 0, max: _maxPriceCents);
  final condition = _condition(body);
  final category = _category(body);
  final imageIds = stringList(body, 'imageIds', maxItems: 3);

  return req.backend.mutate((db) {
    final row = <String, dynamic>{
      'id': db.nextId('mk'),
      'title': title,
      'description': description,
      'contact': contact,
      'priceCents': priceCents,
      'condition': condition,
      'category': category,
      'status': 'onSale',
      'imageIds': imageIds,
      'sellerId': user.id,
      'sellerName': user.name,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    db.market.add(row);
    return marketView(row, user.id);
  });
}

Object? _detail(MockRequest req) {
  final user = requireUser(req);
  final row = findRow(req.backend.db.market, req.param('id'), what: '物品');
  if (row['status'] == 'deleted') notFound('物品已被删除');
  return marketView(row, user.id);
}

Object? _update(MockRequest req) {
  final user = requireUser(req);
  final body = req.json;

  return req.backend.mutate((db) {
    final row = findRow(db.market, req.param('id'), what: '物品');
    _requireOwnerOrAdmin(row['sellerId'], user, '只能编辑自己发布的物品');

    if (body.containsKey('title')) {
      row['title'] = requiredString(body, 'title', label: '标题', maxLength: 40);
    }
    if (body.containsKey('description')) {
      row['description'] =
          requiredString(body, 'description', label: '描述', maxLength: 500);
    }
    if (body.containsKey('contact')) {
      row['contact'] =
          requiredString(body, 'contact', label: '联系方式', maxLength: 60);
    }
    if (body.containsKey('priceCents')) {
      row['priceCents'] = requiredInt(body, 'priceCents',
          label: '价格', min: 0, max: _maxPriceCents);
    }
    if (body.containsKey('condition')) {
      row['condition'] = _condition(body);
    }
    if (body.containsKey('category')) {
      row['category'] = _category(body);
    }
    if (body.containsKey('imageIds')) {
      row['imageIds'] = stringList(body, 'imageIds', maxItems: 3);
    }

    return marketView(row, user.id);
  });
}

Object? _sold(MockRequest req) {
  final user = requireUser(req);
  return req.backend.mutate((db) {
    final row = findRow(db.market, req.param('id'), what: '物品');
    _requireOwnerOrAdmin(row['sellerId'], user, '只能操作自己发布的物品');
    if (row['status'] == 'sold') conflict('ALREADY_SOLD', '这件已经标成已售出了');
    row['status'] = 'sold';
    return marketView(row, user.id);
  });
}

Object? _delete(MockRequest req) {
  final user = requireUser(req);
  return req.backend.mutate((db) {
    final row = findRow(db.market, req.param('id'), what: '物品');
    _requireOwnerOrAdmin(row['sellerId'], user, '只能删除自己发布的物品');
    row['status'] = 'deleted';
    return {'ok': true};
  });
}

String _condition(Map<String, dynamic> body) {
  final value = requiredString(body, 'condition', label: '成色', maxLength: 16);
  const allowed = ['newItem', 'likeNew', 'good', 'fair'];
  if (!allowed.contains(value)) {
    invalid({'condition': '成色不在可选范围内'});
  }
  return value;
}

String _category(Map<String, dynamic> body) {
  final value = requiredString(body, 'category', label: '分类', maxLength: 16);
  const allowed = ['book', 'digital', 'daily', 'sports', 'other'];
  if (!allowed.contains(value)) {
    invalid({'category': '分类不在可选范围内'});
  }
  return value;
}

void _requireOwnerOrAdmin(Object? ownerId, CampusUser user, String message) {
  if (ownerId == user.id) return;
  if (can(user.role, Capability.deleteAnyPost)) return;
  forbidden(message);
}

int _price(Map<String, dynamic> row) =>
    row['priceCents'] is int ? row['priceCents'] as int : 0;
