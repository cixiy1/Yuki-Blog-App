import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yuki_blog_app/features/splash/splash_page.dart';

Widget _harness() {
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('主页已就位')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('启动页展示品牌与「为人民服务」标语', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    // 淡入动画进行中。

    expect(find.text('Yuki Blog'), findsOneWidget);
    expect(find.text('为人民服务'), findsOneWidget);
    expect(find.text('yiyu14.top'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);

    // 推过停留时长，让 Timer 走完再结束测试。
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump();
  });

  testWidgets('停留后自动进入主页，返回键不回启动页', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    // 淡入 600ms → 跳转 1600ms → go 后首帧。
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('为人民服务'), findsOneWidget,
        reason: '1.6s 内应仍停在启动页');

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('主页已就位'), findsOneWidget);
    expect(find.text('为人民服务'), findsNothing,
        reason: 'go 是替换栈，启动页不应留在栈底');
  });
}
