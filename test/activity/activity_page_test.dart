import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/features/campus/activity/activity_editor_page.dart';
import 'package:yuki_blog_app/features/campus/activity/activity_list_page.dart';
import 'package:yuki_blog_app/models/campus/campus_activity.dart';

import '../support/campus_fixtures.dart';

Future<void> _pumpList(WidgetTester tester, CampusServices services) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: ActivityListPage(services: services)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('列表只给已通过的活动，待审核的看不见', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    expect(find.text('周五篮球对抗赛'), findsOneWidget);
    expect(find.text('班级团建 · 烧烤'), findsOneWidget);
    expect(find.text('图书馆志愿服务招募'), findsNothing);
    // 学生没有「待审核」这个分段。
    expect(find.byKey(const Key('ac-filter-pending')), findsNothing);
  });

  testWidgets('点卡片进详情，报名后按钮变成取消报名', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    await tester.tap(find.text('班级团建 · 烧烤'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('ac-detail-title'))).data,
      '班级团建 · 烧烤',
    );
    expect(find.byKey(const Key('ac-signup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ac-signup')));
    await _settle(tester);

    expect(find.text('你已报名'), findsOneWidget);
    expect(find.byKey(const Key('ac-cancel-signup')), findsOneWidget);
    expect(find.byKey(const Key('ac-signup')), findsNothing);
  });

  testWidgets('名额满了按钮是「加入候补」，报名后显示候补位次', (tester) async {
    final services = await testServices(loginAs: '20250102');

    // 造一个只有 1 个名额、已被占满的活动。
    final created = await services.activities.create(
      title: '只有一个位置的讲座',
      description: '先到先得',
      location: '报告厅',
      startAt: DateTime.now().add(const Duration(days: 4)),
      signupDeadline: DateTime.now().add(const Duration(days: 2)),
      capacity: 1,
      schoolWide: true,
    );
    await signInAs(services, '20250103');
    await services.activities.review(created.id, approve: true);
    await signInAs(services, '20250104');
    await services.activities.signup(created.id);

    await signInAs(services, '20250101');
    await _pumpList(tester, services);

    await tester.tap(find.text('只有一个位置的讲座'));
    await tester.pumpAndSettle();

    expect(find.text('加入候补'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ac-signup')));
    await _settle(tester);

    expect(find.text('你在候补第 1 位'), findsOneWidget);
  });

  testWidgets('管理员在待审核里驳回活动，状态变成已驳回', (tester) async {
    final services = await testServices(loginAs: '20250103');
    await _pumpList(tester, services);

    await tester.tap(find.byKey(const Key('ac-filter-pending')));
    await _settle(tester);

    expect(find.text('图书馆志愿服务招募'), findsOneWidget);

    await tester.tap(find.text('图书馆志愿服务招募'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ac-approve')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ac-reject')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('ac-reject-reason')),
      '场地与课程冲突，改期后再交',
    );
    await tester.tap(find.byKey(const Key('ac-reject-submit')));
    await tester.pumpAndSettle();

    expect(find.text('已驳回'), findsOneWidget);
    expect(find.text('驳回原因：场地与课程冲突，改期后再交'), findsOneWidget);

    final detail = await services.activities.detail('ac_3');
    expect(detail.status, ActivityStatus.rejected);
  });

  testWidgets('发起活动时空着提交，先被表单校验拦住', (tester) async {
    final services = await testServices(loginAs: '20250102');

    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ActivityEditorPage(services: services)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('ac-submit')));
    await tester.pumpAndSettle();

    expect(find.text('请填写活动名称'), findsOneWidget);
    expect(find.text('请写点活动说明'), findsOneWidget);
  });
}
