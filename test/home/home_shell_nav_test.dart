import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/features/home/home_shell.dart';

import '../support/campus_fixtures.dart';

Widget _harness(CampusServices services, {String location = '/campus'}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (context, state, child) => HomeShell(
          services: services,
          checkUpdates: false,
          child: child,
        ),
        routes: [
          for (final path in ['/home', '/schedule', '/todo', '/campus', '/setting'])
            GoRoute(path: path, builder: (_, _) => const SizedBox.shrink()),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('底栏有四项', (tester) async {
    final services = await testServices();
    await tester.pumpWidget(_harness(services));
    await tester.pump();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 4);
    expect(find.text('动态课程表'), findsWidgets);
    // 「校园服务」同时是底栏标签和当前页标题，出现两次是对的。
    expect(find.text('校园服务'), findsWidgets);
  });

  testWidgets('/campus 高亮第三项', (tester) async {
    final services = await testServices();
    await tester.pumpWidget(_harness(services));
    await tester.pump();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('未读角标只挂在校园服务上', (tester) async {
    final services = await testServices();
    services.unread.value = 3;
    await tester.pumpWidget(_harness(services));
    await tester.pump();

    final badges = tester.widgetList<Badge>(find.byType(Badge)).toList();
    expect(badges.where((b) => b.isLabelVisible).length, 1);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('320dp 窄屏用短标签且不溢出', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final services = await testServices();
    await tester.pumpWidget(_harness(services));
    await tester.pump();

    expect(find.text('课表'), findsOneWidget);
    expect(find.text('服务'), findsOneWidget);
    expect(find.text('动态课程表'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
