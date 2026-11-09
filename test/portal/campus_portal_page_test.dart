import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/features/campus/portal/campus_portal_page.dart';

import '../support/campus_fixtures.dart';

Future<void> _pumpPortal(WidgetTester tester, CampusServices services) async {
  // 信息流在宫格下面，600px 的默认视口会把它挡在屏幕外导致不构建。
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: CampusPortalPage(services: services)),
    ),
  );
  // loading 态有个无限动画，不能 pumpAndSettle；手动推两帧即可。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('身份条显示姓名、角色与信用', (tester) async {
    final services = await testServices();
    await _pumpPortal(tester, services);

    expect(find.text('张小明'), findsOneWidget);
    expect(find.text('学生'), findsOneWidget);
    expect(
      find.textContaining('软件2615 · 信用 72'),
      findsOneWidget,
    );
  });

  testWidgets('三段信息流标题都在，并有内容', (tester) async {
    final services = await testServices();
    await _pumpPortal(tester, services);

    expect(find.text('最新失物招领'), findsOneWidget);
    expect(find.text('最新二手'), findsOneWidget);
    expect(find.text('待接快递'), findsOneWidget);

    // 种子里最新一条失物是「捡到一把黑色雨伞」。
    expect(find.text('捡到一把黑色雨伞'), findsOneWidget);
  });

  testWidgets('未读数体现在消息入口的角标上', (tester) async {
    final services = await testServices();
    await _pumpPortal(tester, services);

    final badge = tester.widget<Badge>(
      find.ancestor(
        of: find.byIcon(Icons.notifications_none_rounded),
        matching: find.byType(Badge),
      ),
    );
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('3'), findsWidgets);
  });
}
