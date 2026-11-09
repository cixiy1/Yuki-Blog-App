import '../../../campus/permissions.dart';
import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';
import 'view_mappers.dart';

void registerExpressHandlers(MockRouter r) {
  r.on('GET', ApiPaths.express, _list);
  r.on('POST', ApiPaths.express, _create);
  r.on('GET', '/express/:id', _detail);
  r.on('POST', '/express/:id/accept', _accept);
  r.on('POST', '/express/:id/deliver', _deliver);
  r.on('POST', '/express/:id/complete', _complete);
  r.on('POST', '/express/:id/cancel', _cancel);
}

String _now() => DateTime.now().toUtc().toIso8601String();

Object? _list(MockRequest req) {
  final user = requireUser(req);
  final uid = user.id;
  final db = req.backend.db;

  var rows = [
    for (final row in db.express)
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
    [for (final row in rows) expressView(row, uid)],
    pageParam(req),
    pageSizeParam(req),
  );
}

Object? _create(MockRequest req) {
  final user = requireUser(req);
  final body = req.json;

  final station = requiredString(body, 'station', label: '取件地点', maxLength: 40);
  final pickupCode =
      requiredString(body, 'pickupCode', label: '取件码', maxLength: 40);
  final deliverTo =
      requiredString(body, 'deliverTo', label: '送达地点', maxLength: 40);
  final note = optionalString(body, 'note', maxLength: 200);
  final rewardCents =
      requiredInt(body, 'rewardCents', label: '酬金', min: 0, max: 100000);
  final deadline = requiredDate(body, 'deadline', label: '送达时限');
  if (!deadline.isAfter(DateTime.now())) invalid({'deadline': '时限要晚于现在'});

  final scope = _scope(body);

  return req.backend.mutate((db) {
    final row = <String, dynamic>{
      'id': db.nextId('ex'),
      'station': station,
      'pickupCode': pickupCode,
      'deliverTo': deliverTo,
      'note': note,
      'rewardCents': rewardCents,
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
    db.express.add(row);
    return expressView(row, user.id);
  });
}

Object? _detail(MockRequest req) {
  final user = requireUser(req);
  final row = findRow(req.backend.db.express, req.param('id'), what: '任务');
  return expressView(row, user.id);
}

Object? _accept(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');

  // 先在锁外挡掉明显不合法的请求，真正改状态时再检一次。
  final preview = findRow(req.backend.db.express, id, what: '任务');
  if (preview['creatorId'] == user.id) forbidden('不能接自己发的任务');
  if (preview['status'] != 'pending') {
    conflict('NOT_PENDING', '这条已经不是待接单状态了');
  }

  return req.backend.mutate((db) {
    final row = findRow(db.express, id, what: '任务');
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
      title: '你的快递被接单了',
      body: '${user.name} 接了你发布的「${row['station']}」代取，取件码只对接单人可见。',
      type: 'expressAccepted',
      refType: 'express',
      refId: id,
    );

    return expressView(row, user.id);
  });
}

Object? _deliver(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');

  return req.backend.mutate((db) {
    final row = findRow(db.express, id, what: '任务');
    if (row['courierId'] != user.id) forbidden('只有接单人可以标记送达');
    if (row['status'] != 'accepted') {
      conflict('BAD_STATUS', '当前状态不能标记送达');
    }

    row['status'] = 'delivered';
    row['deliveredAt'] = _now();

    req.backend.pushMessage(
      userId: '${row['creatorId']}',
      title: '快递已送达',
      body: '${user.name} 说已经放到 ${row['deliverTo']}，记得确认收货。',
      type: 'expressDelivered',
      refType: 'express',
      refId: id,
    );

    return expressView(row, user.id);
  });
}

Object? _complete(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');

  return req.backend.mutate((db) {
    final row = findRow(db.express, id, what: '任务');
    if (row['creatorId'] != user.id) forbidden('只有发布者能确认完成');
    if (row['status'] != 'delivered') {
      conflict('BAD_STATUS', '还没标记送达，不能确认完成');
    }

    row['status'] = 'completed';
    row['completedAt'] = _now();

    // 接单人的完成单数加一；信用分只看评价，不在这里动。
    bumpCompletedTasks(db.users, row['courierId']);

    return expressView(row, user.id);
  });
}

Object? _cancel(MockRequest req) {
  final user = requireUser(req);
  final id = req.param('id');
  final isAdmin = can(user.role, Capability.deleteAnyPost);

  return req.backend.mutate((db) {
    final row = findRow(db.express, id, what: '任务');
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
        body: '${row['creatorName']} 取消了「${row['station']}」的代取任务。',
        type: 'expressAccepted',
        refType: 'express',
        refId: id,
      );
    }

    return expressView(row, user.id);
  });
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
