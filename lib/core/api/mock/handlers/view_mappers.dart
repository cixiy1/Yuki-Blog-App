import '../../../../models/campus/json_utils.dart';

/// 行记录 → 响应 JSON。
///
/// Mock 库里存的是「原始行」，但接口要给前端补上按请求者算出来的字段
/// （`isMine`、取件码脱敏、报名人数）。这些计算全部集中在这里，
/// 保证列表 / 详情 / 门户三个入口的口径一致。

bool _isMine(Map<String, dynamic> row, String? key, String? uid) =>
    uid != null && row[key] == uid;

Map<String, dynamic> lostFoundView(Map<String, dynamic> row, String? uid) => {
      ...row,
      'isMine': _isMine(row, 'authorId', uid),
    };

Map<String, dynamic> marketView(Map<String, dynamic> row, String? uid) => {
      ...row,
      'isMine': _isMine(row, 'sellerId', uid),
    };

Map<String, dynamic> expressView(Map<String, dynamic> row, String? uid) {
  final isOwner = _isMine(row, 'creatorId', uid);
  final isCourier = uid != null && row['courierId'] == uid;
  final canSeeCode = isOwner || isCourier;
  return {
    ...row,
    'pickupCode': canSeeCode ? row['pickupCode'] : '***',
    'isMine': isOwner,
    'isCourier': isCourier,
  };
}

Map<String, dynamic> purchaseView(
  Map<String, dynamic> row,
  String? uid,
  List<Map<String, dynamic>> allReviews,
) {
  final isOwner = _isMine(row, 'creatorId', uid);
  final isCourier = uid != null && row['courierId'] == uid;

  Map<String, dynamic>? myReview;
  if (uid != null) {
    for (final r in allReviews) {
      if (r['taskId'] == row['id'] && r['fromUserId'] == uid) {
        myReview = r;
        break;
      }
    }
  }

  return {
    ...row,
    'isMine': isOwner,
    'isCourier': isCourier,
    'myReview': myReview,
    'reviewedByMe': myReview != null,
  };
}

/// 活动的报名人数与「我的报名」都在这里算，避免各处自己数。
Map<String, dynamic> activityView(
  Map<String, dynamic> row,
  String? uid,
  List<Map<String, dynamic>> allSignups,
) {
  final id = row['id'];
  final forActivity = allSignups.where((s) => s['activityId'] == id);
  final confirmed =
      forActivity.where((s) => s['status'] == 'confirmed').length;
  final waitlisted =
      forActivity.where((s) => s['status'] == 'waitlisted').length;

  Map<String, dynamic>? mine;
  if (uid != null) {
    for (final s in forActivity) {
      if (s['userId'] == uid && s['status'] != 'cancelled') {
        mine = s;
        break;
      }
    }
  }

  return {
    ...row,
    'confirmedCount': confirmed,
    'waitlistCount': waitlisted,
    'mySignup': mine,
    'isMine': _isMine(row, 'organizerId', uid),
  };
}

/// 表单的已提交数与「我提交过没有」。
Map<String, dynamic> formView(
  Map<String, dynamic> row,
  String? uid,
  List<Map<String, dynamic>> allSubmissions,
) {
  final id = row['id'];
  final forForm = allSubmissions.where((s) => s['formId'] == id).toList();
  final mine = uid == null
      ? null
      : forForm.where((s) => s['userId'] == uid).firstOrNull;
  return {
    ...row,
    'submissionCount': forForm.length,
    'mySubmitted': mine != null,
    // 只回自己的答案，方便「再改一遍」时回填。
    'myAnswers': mine?['answers'],
    'isMine': _isMine(row, 'creatorId', uid),
  };
}

List<Map<String, dynamic>> signupsFor(
  List<Map<String, dynamic>> allSignups,
  String activityId,
) =>
    [
      for (final s in allSignups)
        if (s['activityId'] == activityId) s,
    ];

/// 按创建时间倒序（最新的在前）。
int byNewest(Map<String, dynamic> a, Map<String, dynamic> b) =>
    asString(b['createdAt']).compareTo(asString(a['createdAt']));
