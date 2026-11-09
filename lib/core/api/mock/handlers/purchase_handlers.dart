import '../../../campus/credit_engine.dart';
import '../../../campus/permissions.dart';
import '../../../../models/campus/review.dart';
import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';
import 'view_mappers.dart';

void registerPurchaseHandlers(MockRouter r) {
  r.on('GET', ApiPaths.purchases, _list);
  r.on('POST', ApiPaths.purchases, _create);
  r.on('GET', '/purchases/:id', _detail);
  r.on('POST', '/purchases/:id/accept', _accept);
  r.on('POST', '/purchases/:id/deliver', _deliver);
  r.on('POST', '/purchases/:id/complete', _complete);
  r.on('POST', '/purchases/:id/cancel', _cancel);
  r.on('GET', '/purchases/:id/reviews', _reviews);
  r.on('POST', '/purchases/:id/reviews', _createReview);
}

String _now() => DateTime.now().toUtc().toIso8601String();

Object? _list(MockRequest req) {
  final user = requireUser(req);
  final uid = user.id;
  final db = req.backend.db;

  var rows = [
    for (final row in db.purchases)
      if (visibleToUser(row, user, users: db.users)) row,
  ];

  final status = req.query['status'] ?? 'active';
  rows = switch (status) {
    'all' => rows,
    'pending' => [
        for (final row in rows)
          if (row['status'] == 'pending') row,
      ],
    'finished' => [
        for (final row in rows)
          if (row['status'] == 'completed' || row['status'] == 'cancelled') row,
      ],
    _ => [
        for (final row in rows)
          if (row['status'] == 'pending' ||
              row['status'] == 'accepted' ||
              row['status'] == 'delivered')
            row,
      ],
  };

  if (req.query['mine'] == '1') {
    rows = [
      for (final row in rows)
        if (row['creatorId'] == uid) row,
    ];
  }
  if (req.query['courier'] == '1') {
    rows = [
      for (final row in rows)
        if (row['courierId'] == uid) row,
    ];
  }

  // 「待接单」是给别人看的：自己发的单自己接不了，不该混在里面。
  if (status == 'pending' && req.query['mine'] != '1') {
    rows = [
      for (final row in rows)
        if (row['creatorId'] != uid) row,
    ];
  }

  rows.sort(byNewest);

  return paginate(
    [for (final row in rows) purchaseView(row, uid, db.reviews)],
    pageParam(req),
    pageSizeParam(req),
  );
}

Object? _create(MockRequest req) {
  final user = requireUser(req);
  final body = req.json;

  final title = requiredString(body, 'title', label: '标题', maxLength: 40);
  final note = optionalString(body, 'note', maxLength: 200);
  final fromPlace =
      requiredString(body, 'fromPlace', label: '出发地点', maxLength: 40);
  final toPlace =
      requiredString(body, 'toPlace', label: '送达地点', maxLength: 40);
  final amountCents =
      requiredInt(body, 'amountCents', label: '金额', min: 0, max: 1000000);
  final deadline = requiredDate(body, 'deadline', label: '送达时限');
  if (!deadline.isAfter(DateTime.now())) invalid({'deadline': '时限要晚于现在'});

  final payment = _paymentMethod(body);
  final items = _items(body);
  final scope = _scope(body);

  return req.backend.mutate((db) {
    final row = <String, dynamic>{
      'id': db.nextId('pu'),
      'title': title,
      'note': note,
      'fromPlace': fromPlace,
      'toPlace': toPlace,
      'items': items,
      'amountCents': amountCents,
      'paymentMethod': payment,
      'deadline': deadline.toUtc().toIso8601String(),
      'createdAt': _now(),
      'acceptedAt': null,
      'deliveredAt': null,
      'completedAt': null,
      'creatorId': user.id,
      'creatorName': user.name,
      'courierId': null,
      'courierName': null,
      'status': 'pending',
      'scope': scope,
    };
    db.purchases.add(row);
    return purchaseView(row, user.id, db.reviews);
  });
}

Object? _detail(MockRequest req) {
  final user = requireUser(req);
  final db = req.backend.db;
  final row = findRow(db.purchases, req.param('id'), what: '任务');
  return purchaseView(row, user.id, db.reviews);
}

Object? _accept(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');

  final preview = findRow(req.backend.db.purchases, id, what: '任务');
  if (preview['creatorId'] == user.id) forbidden('不能接自己发的任务');
  if (preview['status'] != 'pending') {
    conflict('NOT_PENDING', '这条已经不是待接单状态了');
  }

  return req.backend.mutate((db) {
    final row = findRow(db.purchases, id, what: '任务');
    if (row['creatorId'] == user.id) forbidden('不能接自己发的任务');
    if (row['status'] != 'pending') {
      conflict('NOT_PENDING', '手慢了，这条已被别人接走');
    }

    row['status'] = 'accepted';
    row['courierId'] = user.id;
    row['courierName'] = user.name;
    row['acceptedAt'] = _now();

    req.backend.pushMessage(
      userId: '${row['creatorId']}',
      title: '代买被接单了',
      body: '${user.name} 接下了「${row['title']}」，金额 ${row['amountCents']} 分，线下结算。',
      type: 'purchaseAccepted',
      refType: 'purchase',
      refId: id,
    );

    return purchaseView(row, user.id, db.reviews);
  });
}

Object? _deliver(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');

  return req.backend.mutate((db) {
    final row = findRow(db.purchases, id, what: '任务');
    if (row['courierId'] != user.id) forbidden('只有接单人可以标记送达');
    if (row['status'] != 'accepted') {
      conflict('BAD_STATUS', '当前状态不能标记送达');
    }

    row['status'] = 'delivered';
    row['deliveredAt'] = _now();

    req.backend.pushMessage(
      userId: '${row['creatorId']}',
      title: '东西已送到',
      body: '${user.name} 已送达「${row['title']}」，确认后可互相评价。',
      type: 'purchaseCompleted',
      refType: 'purchase',
      refId: id,
    );

    return purchaseView(row, user.id, db.reviews);
  });
}

Object? _complete(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');

  return req.backend.mutate((db) {
    final row = findRow(db.purchases, id, what: '任务');
    if (row['creatorId'] != user.id) forbidden('只有发布者能确认完成');
    if (row['status'] != 'delivered') {
      conflict('BAD_STATUS', '还没标记送达，不能确认完成');
    }

    row['status'] = 'completed';
    row['completedAt'] = _now();
    bumpCompletedTasks(db.users, row['courierId']);

    return purchaseView(row, user.id, db.reviews);
  });
}

Object? _cancel(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');
  final isAdmin = can(user.role, Capability.deleteAnyPost);

  return req.backend.mutate((db) {
    final row = findRow(db.purchases, id, what: '任务');
    if (row['creatorId'] != user.id && !isAdmin) {
      forbidden('只有发布者能取消');
    }
    final status = row['status'];
    if (status == 'completed' || status == 'cancelled') {
      conflict('BAD_STATUS', '这条已经结束了');
    }

    row['status'] = 'cancelled';

    final courierId = row['courierId'];
    if (courierId is String && courierId.isNotEmpty && courierId != user.id) {
      req.backend.pushMessage(
        userId: courierId,
        title: '任务被取消了',
        body: '${row['creatorName']} 取消了「${row['title']}」。',
        type: 'purchaseAccepted',
        refType: 'purchase',
        refId: id,
      );
    }

    return purchaseView(row, user.id, db.reviews);
  });
}

Object? _reviews(MockRequest req) {
  requireUser(req);
  final id = req.param('id');
  final db = req.backend.db;
  findRow(db.purchases, id, what: '任务');

  final rows = [
    for (final row in db.reviews)
      if (row['taskId'] == id) row,
  ]..sort(byNewest);

  return {'items': rows};
}

Object? _createReview(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');
  final body = req.json;

  final stars = requiredInt(body, 'stars', label: '星级', min: 1, max: 5);
  final tags = stringList(body, 'tags', maxItems: 4);
  final comment = optionalString(body, 'comment', maxLength: 200);

  return req.backend.mutate((db) {
    final task = findRow(db.purchases, id, what: '任务');
    if (task['status'] != 'completed') {
      conflict('BAD_STATUS', '任务完成后才能评价');
    }

    final isCreator = task['creatorId'] == user.id;
    final isCourier = task['courierId'] == user.id;
    if (!isCreator && !isCourier) forbidden('只有任务双方可以评价');

    final existing = db.reviews.where(
      (row) => row['taskId'] == id && row['fromUserId'] == user.id,
    );
    if (existing.isNotEmpty) conflict('ALREADY_REVIEWED', '这条任务你已经评过了');

    final toUserId = isCreator ? task['courierId'] : task['creatorId'];
    final toUserName = isCreator ? task['courierName'] : task['creatorName'];
    if (toUserId is! String || toUserId.isEmpty) {
      conflict('NO_COUNTERPART', '这条任务还没有对方');
    }

    final row = <String, dynamic>{
      'id': db.nextId('rv'),
      'taskId': id,
      'taskType': 'purchase',
      'fromUserId': user.id,
      'fromUserName': user.name,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'stars': stars,
      'tags': tags,
      'comment': comment,
      'createdAt': _now(),
    };
    db.reviews.add(row);

    // 评价落地即结算信用分：被评价人的分与评价数一起变。
    for (final u in db.users) {
      if (u['id'] != toUserId) continue;
      final current = u['creditScore'] is int ? u['creditScore'] as int : kInitialCredit;
      final count = u['reviewCount'] is int ? u['reviewCount'] as int : 0;
      final next = applyReviewToCredit(current, stars);
      u['creditScore'] = next;
      u['reviewCount'] = count + 1;

      if (next != current) {
        req.backend.pushMessage(
          userId: toUserId,
          title: '信用分有变动',
          body: '${user.name} 给了你 $stars 星评价，信用分 ${next - current >= 0 ? '+' : ''}${next - current}，现在 $next 分。',
          type: 'creditChanged',
          refType: 'purchase',
          refId: id,
        );
      }
      break;
    }

    return Review.fromJson(row).toJson();
  });
}

String _paymentMethod(Map<String, dynamic> body) {
  final raw = body['paymentMethod'];
  if (raw == null) return 'wechat';
  final value = '$raw';
  const allowed = ['wechat', 'alipay', 'cash'];
  if (!allowed.contains(value)) {
    invalid({'paymentMethod': '收款方式只能是 wechat / alipay / cash'});
  }
  return value;
}

List<Map<String, dynamic>> _items(Map<String, dynamic> body) {
  final raw = body['items'];
  if (raw is! List || raw.isEmpty) invalid({'items': '至少写一样要买的东西'});
  if (raw.length > 10) invalid({'items': '最多写 10 样'});

  return [
    for (final entry in raw)
      if (entry is Map)
        {
          'name': requiredString(
            entry.cast<String, dynamic>(),
            'name',
            label: '物品名',
            maxLength: 30,
          ),
          'qty': requiredInt(
            entry.cast<String, dynamic>(),
            'qty',
            label: '数量',
            min: 1,
            max: 99,
          ),
          'note': optionalString(
            entry.cast<String, dynamic>(),
            'note',
            maxLength: 60,
          ),
        },
  ];
}

String _scope(Map<String, dynamic> body) {
  final raw = body['scope'];
  if (raw == null) return 'classOnly';
  final value = '$raw';
  if (value != 'classOnly' && value != 'schoolWide') {
    invalid({'scope': '可见范围只能是 classOnly 或 schoolWide'});
  }
  return value;
}
