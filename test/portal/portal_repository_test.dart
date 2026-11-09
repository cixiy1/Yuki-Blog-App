import 'package:flutter_test/flutter_test.dart';

import '../support/campus_fixtures.dart';

void main() {
  test('六个角标数字符合种子数据的预期', () async {
    final services = await testServices();
    final summary = await services.portal.summary();

    // 张小明自己发的失物 / 二手 / 代买不计入角标。
    expect(summary.countOf('lostFound'), 2,
        reason: '4 条里有 1 条是他自己的');
    expect(summary.countOf('market'), 4, reason: '5 条在售里 1 条是他自己的');
    expect(summary.countOf('express'), 1, reason: '只有 1 条是他人的待接单');
    expect(summary.countOf('purchase'), 0, reason: '唯一待接的那条是他自己发的');
    expect(summary.countOf('forms'), 1, reason: '2 张表里 1 张已关闭');
    expect(summary.countOf('activityPendingReview'), 0,
        reason: '学生看不到待审核角标');
  });

  test('待审核活动只有管理员看得到', () async {
    // 班委能发活动但不能自己批，所以这个角标对他是 0。
    final committee = await testServices(loginAs: '20250102');
    final forCommittee = await committee.portal.summary();
    expect(forCommittee.countOf('activityPendingReview'), 0);

    final admin = await testServices(loginAs: '20250103');
    final forAdmin = await admin.portal.summary();
    expect(forAdmin.countOf('activityPendingReview'), 1);
  });

  test('三段信息流各不超过 3 条，且未读数与消息表一致', () async {
    final services = await testServices();
    final summary = await services.portal.summary();

    expect(summary.latestLostFound.length, lessThanOrEqualTo(3));
    expect(summary.latestMarket.length, lessThanOrEqualTo(3));
    expect(summary.pendingExpress.length, lessThanOrEqualTo(3));

    final real = await services.messages.unreadCount();
    expect(summary.unread, real);
    expect(summary.unread, 3, reason: '种子里给张小明留了 3 条未读');
  });
}
