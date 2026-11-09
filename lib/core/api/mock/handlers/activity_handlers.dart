import '../../../campus/permissions.dart';
import '../../../campus/waitlist_engine.dart';
import '../../../../models/campus/campus_user.dart';
import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';
import 'view_mappers.dart';

void registerActivityHandlers(MockRouter r) {
  r.on('GET', ApiPaths.activities, _list);
  r.on('POST', ApiPaths.activities, _create);
  r.on('GET', ApiPaths.activitiesPendingReview, _pendingReview);
  r.on('GET', '/activities/:id', _detail);
  r.on('PATCH', '/activities/:id', _update);
  r.on('POST', '/activities/:id/review', _review);
  r.on('POST', '/activities/:id/signup', _signup);
  r.on('POST', '/activities/:id/cancel-signup', _cancelSignup);
  r.on('GET', '/activities/:id/signups', _signupList);
  r.on('POST', '/activities/:id/cancel', _cancel);
}

String _now() => DateTime.now().toUtc().toIso8601String();

/// 已通过且已开始的活动按「已结束」返回。
///
/// 这是算出来的展示状态，不落盘：每次读都现算，免得为了一个时间判断
/// 反复写数据库。库里只存 通过 / 待审 / 驳回 / 取消 四种真实状态。
Map<String, dynamic> _effective(Map<String, dynamic> row) {
  if (row['status'] != 'approved') return row;
  final start = DateTime.tryParse('${row['startAt']}');
  if (start == null || DateTime.now().isBefore(start)) return row;
  return {...row, 'status': 'finished'};
}

Object? _list(MockRequest req) {
  final user = requireUser(req);
  final uid = user.id;
  final db = req.backend.db;
  final filter = req.query['filter'] ?? 'open';
  if (filter == 'pending' && !can(user.role, Capability.reviewActivity)) {
    forbidden('只有管理员能看待审核队列');
  }

  var rows = [
    for (final row in db.activities)
      if (visibleToUser(row, user, users: db.users, ownerKey: 'organizerId'))
        _effective(row),
  ];

  rows = switch (filter) {
    'all' => rows,
    'mine' => [
        for (final row in rows)
          if (row['organizerId'] == uid) row,
      ],
    'joined' => [
        for (final row in rows)
          if (_hasActiveSignup(db.signups, '${row['id']}', uid)) row,
      ],
    // 待审核队列给管理员看，普通用户拿不到。
    'pending' => [
        for (final row in rows)
          if (row['status'] == 'pendingReview') row,
      ],
    _ => [
        for (final row in rows)
          if (row['status'] == 'approved') row,
      ],
  };

  final keyword = (req.query['q'] ?? '').trim();
  if (keyword.isNotEmpty) {
    rows = [
      for (final row in rows)
        if ('${row['title']}${row['description']}${row['location']}'
            .contains(keyword))
          row,
    ];
  }

  // 活动按开场时间正序：最近要开始的排前面，比按发布时间排有用。
  rows.sort((a, b) {
    final cmp = '${a['startAt']}'.compareTo('${b['startAt']}');
    return cmp != 0 ? cmp : byNewest(a, b);
  });

  return paginate(
    [
      for (final row in rows) activityView(row, uid, db.signups),
    ],
    pageParam(req),
    pageSizeParam(req),
  );
}

Object? _pendingReview(MockRequest req) {
  requireRole(req, min: UserRole.admin);
  final user = requireUser(req);
  final db = req.backend.db;
  final rows = [
    for (final row in db.activities)
      if (row['status'] == 'pendingReview') row,
  ]..sort(byNewest);
  return paginate(
    [for (final row in rows) activityView(row, user.id, db.signups)],
    pageParam(req),
    pageSizeParam(req),
  );
}

Object? _detail(MockRequest req) {
  final user = requireUser(req);
  final row = findRow(req.backend.db.activities, req.param('id'), what: '活动');
  return activityView(_effective(row), user.id, req.backend.db.signups);
}

Object? _create(MockRequest req) {
  final user = requireRole(req);
  final body = req.json;

  final draft = _readDraft(body);
  final scope = _scope(body);

  return req.backend.mutate((db) {
    final row = <String, dynamic>{
      'id': db.nextId('ac'),
      'title': draft.title,
      'description': draft.description,
      'location': draft.location,
      'startAt': draft.startAt!.toUtc().toIso8601String(),
      'endAt': draft.endAt?.toUtc().toIso8601String(),
      'signupDeadline': draft.signupDeadline!.toUtc().toIso8601String(),
      'capacity': draft.capacity,
      'imageIds': draft.imageIds,
      'organizerId': user.id,
      'organizerName': user.name,
      'scope': scope,
      'status': 'pendingReview',
      'rejectReason': null,
      'reviewedBy': null,
      'reviewedAt': null,
      'createdAt': _now(),
    };
    db.activities.add(row);

    // 活动得先过审。通知管理员，省得他们靠刷新碰运气。
    for (final u in db.users) {
      if (u['id'] == user.id) continue;
      if (u['role'] != 'admin') continue;
      req.backend.pushMessage(
        userId: '${u['id']}',
        title: '有活动待审核',
        body: '${user.name} 发起了「${draft.title}」，等待你审核。',
        type: 'activityPendingReview',
        refType: 'activity',
        refId: '${row['id']}',
      );
    }

    return activityView(row, user.id, db.signups);
  });
}

Object? _update(MockRequest req) {
  final user = requireUser(req);
  final body = req.json;
  final isAdmin = can(user.role, Capability.deleteAnyPost);
  final draft = _readDraft(body, partial: true);

  final preview =
      findRow(req.backend.db.activities, req.param('id'), what: '活动');
  _requireOrganizer(preview, user, isAdmin);

  final id = '${preview['id']}';
  return req.backend.mutate((db) {
    final row = findRow(db.activities, id, what: '活动');
    _requireOrganizer(row, user, isAdmin);

    final status = row['status'];
    if (status == 'cancelled' || status == 'finished') {
      conflict('BAD_STATUS', '已取消或已结束的活动不能再改');
    }

    draft.applyTo(row);
    _validateRow(row);

    // 组织者改了内容就得重新过审，否则「先发一段合规的、过审后再改」
    // 就成了绕开审核的口子。管理员自己改不重置。
    if (!isAdmin && row['organizerId'] == user.id) {
      row['status'] = 'pendingReview';
      row['reviewedBy'] = null;
      row['reviewedAt'] = null;
      row['rejectReason'] = null;
    }

    return activityView(row, user.id, db.signups);
  });
}

Object? _review(MockRequest req) {
  final user = requireRole(req, min: UserRole.admin);
  final body = req.json;
  final approve = body['approve'] == true;
  final reason = optionalString(body, 'reason', maxLength: 200);
  if (!approve && reason.isEmpty) {
    invalid({'reason': '驳回要写明原因'});
  }

  final preview =
      findRow(req.backend.db.activities, req.param('id'), what: '活动');
  if (preview['status'] != 'pendingReview') {
    conflict('NOT_PENDING_REVIEW', '这个活动不在待审核状态');
  }

  final id = '${preview['id']}';
  return req.backend.mutate((db) {
    final row = findRow(db.activities, id, what: '活动');
    if (row['status'] != 'pendingReview') {
      conflict('NOT_PENDING_REVIEW', '这个活动已经被处理过了');
    }

    row['status'] = approve ? 'approved' : 'rejected';
    row['rejectReason'] = approve ? null : reason;
    row['reviewedBy'] = user.name;
    row['reviewedAt'] = _now();

    req.backend.pushMessage(
      userId: '${row['organizerId']}',
      title: approve ? '活动已通过审核' : '活动被驳回',
      body: approve
          ? '「${row['title']}」已上架，同学们可以报名了。'
          : '「${row['title']}」被驳回：$reason',
      type: approve ? 'activityApproved' : 'activityRejected',
      refType: 'activity',
      refId: id,
    );

    return activityView(row, user.id, db.signups);
  });
}

Object? _signup(MockRequest req) {
  final user = requireUser(req);
  final id = '${req.param('id')}';

  final preview = findRow(req.backend.db.activities, id, what: '活动');
  _requireSignupOpen(preview, user);

  return req.backend.mutate((db) {
    final row = findRow(db.activities, id, what: '活动');
    _requireSignupOpen(row, user);

    final active = activeSignups(db.signups, id);
    if (active.any((s) => s['userId'] == user.id)) {
      conflict('ALREADY_SIGNED', '你已经报过名了');
    }

    final capacity = row['capacity'] is int ? row['capacity'] as int : 0;
    final confirmedNow =
        active.where((s) => s['status'] == 'confirmed').length;
    final confirmed = confirmedNow < capacity;

    // 取消过的记录复用同一条，保证「一人一活动一条」。
    Map<String, dynamic>? mine;
    for (final s in db.signups) {
      if (s['activityId'] == id && s['userId'] == user.id) {
        mine = s;
        break;
      }
    }

    final target = mine ??
        <String, dynamic>{
          'id': db.nextId('sg'),
          'activityId': id,
          'userId': user.id,
          'userName': user.name,
          'className': user.className,
          'createdAt': _now(),
          'promotedAt': null,
        };

    target['status'] = confirmed ? 'confirmed' : 'waitlisted';
    target['queuePosition'] =
        confirmed ? null : nextQueuePosition(db.signups, id);
    target['createdAt'] = _now();
    target['promotedAt'] = null;
    if (mine == null) db.signups.add(target);

    return activityView(row, user.id, db.signups);
  });
}

Object? _cancelSignup(MockRequest req) {
  final user = requireUser(req);
  final id = '${req.param('id')}';

  return req.backend.mutate((db) {
    final row = findRow(db.activities, id, what: '活动');
    Map<String, dynamic>? mine;
    for (final s in db.signups) {
      if (s['activityId'] == id &&
          s['userId'] == user.id &&
          s['status'] != 'cancelled') {
        mine = s;
        break;
      }
    }
    if (mine == null) conflict('NOT_SIGNED', '你还没有报名这个活动');

    final wasConfirmed = mine['status'] == 'confirmed';
    mine['status'] = 'cancelled';
    mine['queuePosition'] = null;

    if (wasConfirmed) {
      final promoted = firstWaitlisted(db.signups, id);
      if (promoted != null) {
        promoted['status'] = 'confirmed';
        promoted['queuePosition'] = null;
        promoted['promotedAt'] = _now();
        req.backend.pushMessage(
          userId: '${promoted['userId']}',
          title: '候补递补成功',
          body: '有人退出了「${row['title']}」，你已转成正式报名。',
          type: 'activityPromoted',
          refType: 'activity',
          refId: id,
        );
      }
    }

    renumberWaitlist(db.signups, id);
    return activityView(row, user.id, db.signups);
  });
}

Object? _signupList(MockRequest req) {
  final user = requireUser(req);
  final row = findRow(req.backend.db.activities, req.param('id'), what: '活动');
  final isOrganizer = row['organizerId'] == user.id;
  if (!isOrganizer && !can(user.role, Capability.viewSignupList)) {
    forbidden('只有发起人或管理员能看报名名单');
  }

  final id = '${row['id']}';
  final rows = activeSignups(req.backend.db.signups, id)
    ..sort((a, b) {
      // 正式报名在前，候补按位次跟在后面。
      final byStatus = '${a['status']}'.compareTo('${b['status']}');
      if (byStatus != 0) return a['status'] == 'confirmed' ? -1 : 1;
      if (a['status'] == 'waitlisted') {
        final pa = a['queuePosition'] is int ? a['queuePosition'] as int : 0;
        final pb = b['queuePosition'] is int ? b['queuePosition'] as int : 0;
        if (pa != pb) return pa.compareTo(pb);
      }
      return '${a['createdAt']}'.compareTo('${b['createdAt']}');
    });

  return paginate(rows, pageParam(req), pageSizeParam(req));
}

Object? _cancel(MockRequest req) {
  final user = requireUser(req);
  final isAdmin = can(user.role, Capability.deleteAnyPost);
  final preview =
      findRow(req.backend.db.activities, req.param('id'), what: '活动');
  _requireOrganizer(preview, user, isAdmin);
  final id = '${preview['id']}';

  return req.backend.mutate((db) {
    final row = findRow(db.activities, id, what: '活动');
    _requireOrganizer(row, user, isAdmin);
    final status = row['status'];
    if (status == 'cancelled' || status == 'finished') {
      conflict('BAD_STATUS', '这个活动已经结束了');
    }

    row['status'] = 'cancelled';

    // 报了名的都要知道，不能只改状态了事。
    for (final s in activeSignups(db.signups, id)) {
      s['status'] = 'cancelled';
      s['queuePosition'] = null;
      req.backend.pushMessage(
        userId: '${s['userId']}',
        title: '活动已取消',
        body: '「${row['title']}」被取消了，不用再去了。',
        type: 'activityCancelled',
        refType: 'activity',
        refId: id,
      );
    }

    return activityView(row, user.id, db.signups);
  });
}

// ── 校验与字段读取 ─────────────────────────────────────────

bool _hasActiveSignup(
  List<Map<String, dynamic>> signups,
  String activityId,
  String uid,
) =>
    signups.any((s) =>
        s['activityId'] == activityId &&
        s['userId'] == uid &&
        s['status'] != 'cancelled');

void _requireOrganizer(
  Map<String, dynamic> row,
  CampusUser user,
  bool isAdmin,
) {
  if (row['organizerId'] != user.id && !isAdmin) {
    forbidden('只有发起人能改这个活动');
  }
}

void _requireSignupOpen(Map<String, dynamic> row, CampusUser user) {
  if (row['status'] != 'approved') {
    conflict('NOT_OPEN', '这个活动当前不能报名');
  }
  if (row['organizerId'] == user.id) {
    forbidden('不能报名自己发起的活动');
  }
  final deadline = DateTime.tryParse('${row['signupDeadline']}');
  if (deadline != null && DateTime.now().isAfter(deadline)) {
    conflict('SIGNUP_CLOSED', '报名已经截止了');
  }
  final start = DateTime.tryParse('${row['startAt']}');
  if (start != null && DateTime.now().isAfter(start)) {
    conflict('SIGNUP_CLOSED', '活动已经开始了');
  }
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

/// 一次新建 / 编辑读出来的全部字段。
///
/// 新建时全量校验；编辑时只校验传了的字段，没传的不动。
class _Draft {
  _Draft({
    this.title,
    this.description,
    this.location,
    this.startAt,
    this.endAt,
    this.signupDeadline,
    this.capacity,
    this.imageIds,
    this.clearEndAt = false,
  });

  final String? title;
  final String? description;
  final String? location;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? signupDeadline;
  final int? capacity;
  final List<String>? imageIds;

  /// 编辑时明确清空结束时间。
  final bool clearEndAt;

  void applyTo(Map<String, dynamic> row) {
    if (title != null) row['title'] = title;
    if (description != null) row['description'] = description;
    if (location != null) row['location'] = location;
    if (startAt != null) row['startAt'] = startAt!.toUtc().toIso8601String();
    if (clearEndAt) {
      row['endAt'] = null;
    } else if (endAt != null) {
      row['endAt'] = endAt!.toUtc().toIso8601String();
    }
    if (signupDeadline != null) {
      row['signupDeadline'] = signupDeadline!.toUtc().toIso8601String();
    }
    if (capacity != null) row['capacity'] = capacity;
    if (imageIds != null) row['imageIds'] = imageIds;
  }
}

_Draft _readDraft(Map<String, dynamic> body, {bool partial = false}) {
  // 新建时每个字段都是必填；编辑时只认请求里真的带上来的字段，
  // 没带的一律不动，也不能拿「没带」当「填了空」。
  bool has(String key) => !partial || body.containsKey(key);

  final title = has('title')
      ? requiredString(body, 'title', label: '活动名称', maxLength: 40)
      : null;
  final description = has('description')
      ? requiredString(body, 'description', label: '活动说明', maxLength: 1000)
      : null;
  final location = has('location')
      ? requiredString(body, 'location', label: '活动地点', maxLength: 40)
      : null;
  final startAt =
      has('startAt') ? requiredDate(body, 'startAt', label: '开始时间') : null;
  final endAt = has('endAt') ? optionalDate(body, 'endAt') : null;
  final deadline = has('signupDeadline')
      ? requiredDate(body, 'signupDeadline', label: '报名截止')
      : null;
  final capacity = has('capacity')
      ? requiredInt(body, 'capacity', label: '名额', min: 1, max: 500)
      : null;
  final imageIds = has('imageIds') ? stringList(body, 'imageIds') : null;

  _requireChronology(startAt: startAt, endAt: endAt, deadline: deadline);

  return _Draft(
    title: title,
    description: description,
    location: location,
    startAt: startAt,
    endAt: endAt,
    signupDeadline: deadline,
    capacity: capacity,
    imageIds: imageIds,
    clearEndAt: partial && body.containsKey('endAt') && body['endAt'] == null,
  );
}

/// 三个时间点必须前后一致。只校验同时给出的组合——编辑时可能只改其中一个，
/// 那种情况由 [_validateRow] 拿合并后的行再校一次。
void _requireChronology({
  DateTime? startAt,
  DateTime? endAt,
  DateTime? deadline,
}) {
  if (startAt != null && endAt != null && endAt.isBefore(startAt)) {
    invalid({'endAt': '结束时间不能早于开始时间'});
  }
  if (startAt != null && deadline != null && !deadline.isBefore(startAt)) {
    invalid({'signupDeadline': '报名截止要早于活动开始'});
  }
}

/// 合并后的整行再校一次时间关系。
void _validateRow(Map<String, dynamic> row) {
  DateTime? parse(Object? raw) => DateTime.tryParse('$raw');
  _requireChronology(
    startAt: parse(row['startAt']),
    endAt: parse(row['endAt']),
    deadline: parse(row['signupDeadline']),
  );
}
