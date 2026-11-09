import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/models/campus/campus_activity.dart';

import '../support/campus_fixtures.dart';

/// 造一个已过审、马上能报名的活动。李思远（班委）发起，王老师（管理员）批。
Future<CampusActivity> _approvedActivity(
  CampusServices services, {
  String title = '周三晚自习分享会',
  int capacity = 2,
  DateTime? startAt,
  DateTime? deadline,
}) async {
  final start = startAt ?? DateTime.now().add(const Duration(days: 3));
  final created = await services.activities.create(
    title: title,
    description: '随便聊聊',
    location: '教学楼 A301',
    startAt: start,
    signupDeadline: deadline ?? start.subtract(const Duration(days: 1)),
    capacity: capacity,
    schoolWide: true,
  );
  await signInAs(services, '20250103');
  final approved = await services.activities.review(created.id, approve: true);
  return approved;
}

void main() {
  test('默认列表只给已通过的活动，待审核的不出现', () async {
    final services = await testServices();

    final open = await services.activities.list();
    final titles = open.items.map((a) => a.title).toList();

    expect(titles, contains('周五篮球对抗赛'));
    expect(titles, contains('班级团建 · 烧烤'));
    expect(titles, isNot(contains('图书馆志愿服务招募')));

    // 待审核队列是管理员的工作台，学生连看都不该看到。
    await expectLater(
      services.activities.list(filter: 'pending'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'FORBIDDEN')),
    );

    await signInAs(services, '20250103');
    final pending = await services.activities.list(filter: 'pending');
    expect(pending.items.map((a) => a.title), contains('图书馆志愿服务招募'));
  });

  test('满员活动返回自己的候补位次', () async {
    final services = await testServices();

    final activity = await services.activities.detail('ac_1');
    expect(activity.confirmedCount, 2);
    expect(activity.waitlistCount, 2);
    expect(activity.isFull, isTrue);
    expect(activity.mySignup?.status, SignupStatus.waitlisted);
    expect(activity.mySignup?.queuePosition, 1);
  });

  test('名额没满就直接报名成功', () async {
    final services = await testServices();

    final joined = await services.activities.signup('ac_2');

    expect(joined.mySignup?.status, SignupStatus.confirmed);
    expect(joined.confirmedCount, 1);
  });

  test('重复报名被挡回去', () async {
    final services = await testServices();

    await services.activities.signup('ac_2');

    await expectLater(
      services.activities.signup('ac_2'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'ALREADY_SIGNED')),
    );
  });

  test('满员后报名自动进候补，位次接在队尾', () async {
    final services = await testServices(loginAs: '20250102');
    final activity = await _approvedActivity(services, capacity: 1);

    // 张小明 抢到唯一的名额。
    await signInAs(services, '20250101');
    final first = await services.activities.signup(activity.id);
    expect(first.mySignup?.status, SignupStatus.confirmed);

    // 陈佳仪 只能候补。
    await signInAs(services, '20250104');
    final second = await services.activities.signup(activity.id);
    expect(second.mySignup?.status, SignupStatus.waitlisted);
    expect(second.mySignup?.queuePosition, 1);
    expect(second.confirmedCount, 1);
    expect(second.waitlistCount, 1);
  });

  test('取消正式名额后候补第一位自动递补，并收到消息', () async {
    final services = await testServices(loginAs: '20250102');
    final activity = await _approvedActivity(services, capacity: 1);

    await signInAs(services, '20250101');
    await services.activities.signup(activity.id);
    await signInAs(services, '20250104');
    await services.activities.signup(activity.id);

    // 张小明 退出 → 陈佳仪 顶上。
    await signInAs(services, '20250101');
    final after = await services.activities.cancelSignup(activity.id);
    expect(after.mySignup, isNull);
    expect(after.confirmedCount, 1);

    await signInAs(services, '20250104');
    final promoted = await services.activities.detail(activity.id);
    expect(promoted.mySignup?.status, SignupStatus.confirmed);
    expect(promoted.mySignup?.promotedAt, isNotNull);

    final inbox = await services.messages.list();
    expect(
      inbox.items.any((m) => m.type.name == 'activityPromoted'),
      isTrue,
    );
  });

  test('取消候补后位次重排，不留空洞', () async {
    final services = await testServices(loginAs: '20250102');
    final activity = await _approvedActivity(services, capacity: 1);

    await signInAs(services, '20250101');
    await services.activities.signup(activity.id);
    await signInAs(services, '20250104');
    await services.activities.signup(activity.id);
    await signInAs(services, '20250105');
    final third = await services.activities.signup(activity.id);
    expect(third.mySignup?.queuePosition, 2);

    // 第 1 位候补退出，第 2 位补成第 1 位。
    await signInAs(services, '20250104');
    await services.activities.cancelSignup(activity.id);

    await signInAs(services, '20250105');
    final after = await services.activities.detail(activity.id);
    expect(after.mySignup?.queuePosition, 1);
    expect(after.waitlistCount, 1);
  });

  test('只有管理员能审核，班委自己发的活动也审不了', () async {
    final services = await testServices(loginAs: '20250102');
    final created = await services.activities.create(
      title: '周末爬山',
      description: '自备水',
      location: '校门口集合',
      startAt: DateTime.now().add(const Duration(days: 5)),
      signupDeadline: DateTime.now().add(const Duration(days: 4)),
      capacity: 8,
      schoolWide: true,
    );
    expect(created.status, ActivityStatus.pendingReview);

    await expectLater(
      services.activities.review(created.id, approve: true),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'FORBIDDEN')),
    );

    await signInAs(services, '20250103');
    final approved = await services.activities.review(created.id, approve: true);
    expect(approved.status, ActivityStatus.approved);
    expect(approved.reviewedBy, '王老师');
  });

  test('驳回必须写原因，组织者会收到通知', () async {
    final services = await testServices(loginAs: '20250102');
    final created = await services.activities.create(
      title: '通宵自习',
      description: '教室过夜',
      location: '教学楼',
      startAt: DateTime.now().add(const Duration(days: 2)),
      signupDeadline: DateTime.now().add(const Duration(days: 1)),
      capacity: 10,
      schoolWide: true,
    );

    await signInAs(services, '20250103');
    await expectLater(
      services.activities.review(created.id, approve: false),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'VALIDATION_FAILED')),
    );

    final rejected = await services.activities.review(
      created.id,
      approve: false,
      reason: '不允许在教室过夜',
    );
    expect(rejected.status, ActivityStatus.rejected);
    expect(rejected.rejectReason, '不允许在教室过夜');

    await signInAs(services, '20250102');
    final inbox = await services.messages.list();
    expect(
      inbox.items.any((m) => m.type.name == 'activityRejected'),
      isTrue,
    );
  });

  test('过了报名截止就不能再报', () async {
    final services = await testServices(loginAs: '20250102');
    final activity = await _approvedActivity(
      services,
      capacity: 5,
      startAt: DateTime.now().add(const Duration(days: 2)),
      deadline: DateTime.now().subtract(const Duration(hours: 1)),
    );

    await signInAs(services, '20250101');
    await expectLater(
      services.activities.signup(activity.id),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'SIGNUP_CLOSED')),
    );
  });

  test('报名名单只给发起人和管理员', () async {
    final services = await testServices(loginAs: '20250102');

    final list = await services.activities.signups('ac_1');
    expect(list, isNotEmpty);
    expect(list.first.status, SignupStatus.confirmed);

    await signInAs(services, '20250101');
    await expectLater(
      services.activities.signups('ac_1'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'FORBIDDEN')),
    );

    await signInAs(services, '20250103');
    expect(await services.activities.signups('ac_1'), isNotEmpty);
  });

  test('取消活动会清掉所有报名并逐个通知', () async {
    final services = await testServices(loginAs: '20250102');
    final activity = await _approvedActivity(services, capacity: 5);

    await signInAs(services, '20250101');
    await services.activities.signup(activity.id);

    await signInAs(services, '20250102');
    final cancelled = await services.activities.cancel(activity.id);
    expect(cancelled.status, ActivityStatus.cancelled);

    await signInAs(services, '20250101');
    final after = await services.activities.detail(activity.id);
    expect(after.mySignup, isNull);
    expect(after.confirmedCount, 0);

    final inbox = await services.messages.list();
    expect(
      inbox.items.any((m) => m.type.name == 'activityCancelled'),
      isTrue,
    );
  });

  test('组织者改了内容要重新过审，管理员改不重置', () async {
    final services = await testServices(loginAs: '20250102');
    final activity = await _approvedActivity(services, capacity: 5);

    await signInAs(services, '20250102');
    final edited = await services.activities.update(
      activity.id,
      title: '周三晚自习分享会（改期）',
    );
    expect(edited.title, '周三晚自习分享会（改期）');
    expect(edited.status, ActivityStatus.pendingReview);

    await signInAs(services, '20250103');
    final reviewed =
        await services.activities.review(activity.id, approve: true);
    expect(reviewed.status, ActivityStatus.approved);

    final byAdmin = await services.activities.update(
      activity.id,
      description: '管理员补一句说明',
    );
    expect(byAdmin.status, ActivityStatus.approved);
  });

  test('报名截止必须早于活动开始', () async {
    final services = await testServices(loginAs: '20250102');
    final start = DateTime.now().add(const Duration(days: 3));

    await expectLater(
      services.activities.create(
        title: '时间写错的活动',
        description: '截止晚于开始',
        location: '某处',
        startAt: start,
        signupDeadline: start.add(const Duration(hours: 1)),
        capacity: 5,
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'VALIDATION_FAILED')),
    );
  });

  test('学生不能发起活动', () async {
    final services = await testServices();

    await expectLater(
      services.activities.create(
        title: '学生自己组织的活动',
        description: '应该被拦住',
        location: '某处',
        startAt: DateTime.now().add(const Duration(days: 2)),
        signupDeadline: DateTime.now().add(const Duration(days: 1)),
        capacity: 5,
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'FORBIDDEN')),
    );
  });
}
