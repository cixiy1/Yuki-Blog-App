import '../../../campus/permissions.dart';
import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';
import 'view_mappers.dart';

void registerPortalHandlers(MockRouter r) {
  r.on('GET', ApiPaths.portalSummary, _summary);
}

/// 门户一次请求拿齐：六个模块角标 + 未读数 + 三段信息流。
///
/// 拆成六个接口会让首页并发六个请求、六次 setState，没必要。
Object? _summary(MockRequest req) {
  final user = requireUser(req);
  final uid = user.id;
  final db = req.backend.db;

  final lostFound = [
    for (final row in db.lostFound)
      if (row['status'] == 'open' && row['authorId'] != uid) row,
  ]..sort(byNewest);

  final market = [
    for (final row in db.market)
      if (row['status'] == 'onSale' && row['sellerId'] != uid) row,
  ]..sort(byNewest);

  final express = [
    for (final row in db.express)
      if (row['status'] == 'pending' && row['creatorId'] != uid) row,
  ]..sort(byNewest);

  final purchasePending = [
    for (final row in db.purchases)
      if (row['status'] == 'pending' && row['creatorId'] != uid) row,
  ];

  // 「待我填」= 进行中且我还没提交过的表单。
  final formsToFill = [
    for (final form in db.forms)
      if (form['status'] == 'open' &&
          !db.submissions.any(
            (s) => s['formId'] == form['id'] && s['userId'] == uid,
          ))
        form,
  ];

  final pendingReview = can(user.role, Capability.reviewActivity)
      ? db.activities.where((a) => a['status'] == 'pendingReview').length
      : 0;

  final unread = db.messages
      .where((m) => m['userId'] == uid && m['read'] != true)
      .length;

  return {
    'counts': {
      'lostFound': lostFound.length,
      'market': market.length,
      'express': express.length,
      'activityPendingReview': pendingReview,
      'forms': formsToFill.length,
      'purchase': purchasePending.length,
    },
    'unread': unread,
    'latestLostFound': [
      for (final row in lostFound.take(3)) lostFoundView(row, uid),
    ],
    'latestMarket': [
      for (final row in market.take(3)) marketView(row, uid),
    ],
    'pendingExpress': [
      for (final row in express.take(3)) expressView(row, uid),
    ],
  };
}
