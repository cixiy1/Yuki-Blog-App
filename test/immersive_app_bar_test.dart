import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/widgets/immersive_app_bar.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

void main() {
  /// 毛玻璃层 —— **只有一层**（整条统一模糊，不再分带）。
  ///
  /// **四个平台一视同仁**：早先这里按 `blurSupported` 分支，Web 上断言
  /// 「没有 BackdropFilter」——那是误判（把 flexibleSpace 无界高度和引擎
  /// 裁剪混成了一个 bug）。所以 Web 也走整套配方。
  final Matcher showsBlur = findsOneWidget;

  /// 把标题栏塞进一个真实 Scaffold，行为才与线上一致。
  Widget wrap(
    PreferredSizeWidget appBar, {
    Brightness brightness = Brightness.light,
    Widget? drawer,
  }) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(appBar: appBar, drawer: drawer),
    );
  }

  ImmersiveAppBar bar({VoidCallback? onMenu, Widget? leading}) =>
      ImmersiveAppBar(
        title: '动态课程表',
        onMenu: onMenu,
        leading: leading,
      );

  /// 取模糊层的矩形（整条只有一层）。
  Rect glassRect(WidgetTester tester) =>
      tester.getRect(find.byType(BackdropFilter));

  // ── ImmersiveAppBar ──────────────────────────────────────────────────
  group('ImmersiveAppBar', () {
    testWidgets('全程毛玻璃：挂载即铺（贴顶态不再全透明）', (tester) async {
      // 2026-11-09 用户要求「顶部模糊条要全程模糊」——贴顶与滚动态一视同仁，
      // 原先「贴顶全透明、滚过 50px 渐显」的进度机制已删。
      await tester.pumpWidget(wrap(bar()));

      expect(find.byKey(kImmersiveTitleKey), findsOneWidget);
      expect(find.byType(BackdropFilter), showsBlur);
      expect(find.byKey(kImmersiveTintKey), findsOneWidget);
      expect(find.byKey(kImmersiveHighlightKey), findsOneWidget);
    });

    testWidgets('只在顶端画一条细线，标题栏下沿不再有发丝线', (tester) async {
      // 网页版标题栏下沿有 `0 1px 0` 的发丝线，App 上按用户要求去掉了。
      await tester.pumpWidget(wrap(bar()));

      final barRect = tester.getRect(find.byType(ImmersiveAppBar));
      final finder = find.descendant(
        of: find.byType(ImmersiveAppBar),
        matching: find.byType(ColoredBox),
      );
      final lines = [
        for (var i = 0; i < tester.widgetList(finder).length; i++)
          tester.getRect(finder.at(i)),
      ].where((r) => (r.height - 1).abs() < 0.01).toList();

      expect(lines, hasLength(1), reason: '细线只该剩顶部高光那一条');
      expect(lines.single.top, barRect.top);
      expect(lines.single.bottom, lessThan(barRect.bottom));
    });

    testWidgets('Web 也铺 BackdropFilter（引擎裁剪是好的，别再关掉）', (tester) async {
      // 回归记录：这里曾经是「Web 上不铺模糊」。当时的判断依据是
      // 「Web 引擎画 BackdropFilter 不裁剪图层 → 整页糊」，于是 Web 只剩
      // 一层平铺底色 —— 用户看到的「逐渐模糊没效果」就是这么来的。
      //
      // 真因是 flexibleSpace 的无界高度把模糊层撑到了全屏（另一处 bug），
      // 两个问题被当成一个修了。修掉限高后实测：把真机光栅化，逐行量
      // 「竖直硬边」的过渡宽度，CanvasKit 与原生几乎逐行重合。
      await tester.pumpWidget(wrap(bar()));

      expect(find.byType(BackdropFilter), showsBlur);
      // 底色与顶部高光线也都在，观感是叠加出来的
      expect(find.byKey(kImmersiveTintKey), findsOneWidget);
      expect(find.byKey(kImmersiveHighlightKey), findsOneWidget);
    });

    testWidgets('模糊层只有一层，严格盖满标题栏、不糊全屏', (tester) async {
      // 回归：AppBar.flexibleSpace 挂在 OverflowBox(maxHeight: infinity) 下，
      // 不限高时 BackdropFilter 会被撑到全屏 → 用户看到「全屏模糊」。
      await tester.pumpWidget(wrap(bar()));

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final rect = glassRect(tester);

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(rect.top, 0); // 贴屏幕最上沿
      expect(rect.bottom, kToolbarHeight); // 到标题栏下沿为止
      expect(kToolbarHeight, lessThan(screenHeight)); // 就是没糊到全屏
    });

    testWidgets('底色是整条统一的半透明背景色（不再上下渐变）', (tester) async {
      await tester.pumpWidget(wrap(bar()));

      final decoration = (tester
              .widget<DecoratedBox>(find.byKey(kImmersiveTintKey))
              .decoration) as BoxDecoration;

      expect(decoration.gradient, isNull, reason: '模糊不分层，底色也不该渐变');
      expect(decoration.color!.a, closeTo(kImmersiveTintAlpha, 0.001));
    });

    testWidgets('标题栏高度 = 工具栏行（不含状态栏内边距时）', (tester) async {
      await tester.pumpWidget(wrap(bar()));

      expect(tester.getSize(find.byType(ImmersiveAppBar)).height, kToolbarHeight);
    });

    testWidgets('显式 onMenu 点击触发回调', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(bar(onMenu: () => tapped = true)));

      await tester.tap(find.byKey(kImmersiveMenuKey));
      expect(tapped, isTrue);
    });

    testWidgets('不传 onMenu 时点菜单打开 Scaffold 抽屉（默认行为）', (tester) async {
      // 回归：曾在创建 Scaffold 的那个 context 上调 Scaffold.of，
      // 抛「Scaffold.of() called with a context that does not contain a Scaffold」。
      // 现在菜单动作走标题栏自身（Scaffold 之下）的 context。
      await tester.pumpWidget(
        wrap(bar(), drawer: const Drawer(child: Text('抽屉内容'))),
      );

      await tester.tap(find.byKey(kImmersiveMenuKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('抽屉内容'), findsOneWidget);
    });

    testWidgets('没有抽屉、没有 onMenu、不能返回时不放任何左侧按钮', (tester) async {
      await tester.pumpWidget(wrap(bar()));

      expect(find.byKey(kImmersiveMenuKey), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('显式 leading 覆盖默认左侧按钮', (tester) async {
      await tester.pumpWidget(
        wrap(bar(onMenu: () {}, leading: const Icon(Icons.star))),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byKey(kImmersiveMenuKey), findsNothing);
    });

    testWidgets('深色主题正常渲染', (tester) async {
      await tester.pumpWidget(wrap(bar(), brightness: Brightness.dark));

      expect(find.byKey(kImmersiveTitleKey), findsOneWidget);
      expect(find.byType(BackdropFilter), showsBlur);
    });
  });

  // ── ImmersiveScaffold ────────────────────────────────────────────────
  group('ImmersiveScaffold', () {
    Widget page({
      Key bodyKey = const Key('page-body'),
      Widget? drawer,
      String title = '待办',
      bool extendBodyBehindAppBar = true,
    }) {
      return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: ImmersiveScaffold(
          title: title,
          drawer: drawer,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          body: ListView.builder(
            key: bodyKey,
            itemCount: 80,
            itemBuilder: (context, i) =>
                SizedBox(height: 60, child: Text('第 $i 行')),
          ),
        ),
      );
    }

    testWidgets('渲染标题栏与内容，挂载即毛玻璃', (tester) async {
      await tester.pumpWidget(page());

      expect(find.text('待办'), findsOneWidget);
      expect(find.text('第 0 行'), findsOneWidget);
      expect(find.byType(BackdropFilter), showsBlur);
    });

    testWidgets('内容从标题栏底下穿过（默认穿透，玻璃才有东西可糊）', (tester) async {
      await tester.pumpWidget(page());

      // 滚动视口从屏幕顶端开始（内容能钻到标题栏下面）
      expect(
        tester.getTopLeft(find.byKey(const Key('page-body'))).dy,
        0,
      );
      // 但首屏内容靠 MediaQuery 留白避开标题栏（ListView padding 为 null 时
      // 框架会自动套用这段 padding）
      final firstLineAtRest = tester.getTopLeft(find.text('第 0 行')).dy;
      expect(firstLineAtRest, greaterThanOrEqualTo(kToolbarHeight));

      // 滚 60px：首行进入标题栏那条带；玻璃全程常驻，不随滚动变化。
      // 用 jumpTo 而不是 drag：drag 抬手的惯性会把首行直接甩出缓存区。
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(60);
      await tester.pump();
      expect(tester.getTopLeft(find.text('第 0 行')).dy, lessThan(kToolbarHeight));

      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), showsBlur);
    });

    testWidgets('页面内嵌的可滚动组件拖动后玻璃照常常驻（历史回归）', (tester) async {
      // 历史回归：进度机制时代，NotificationListener 会收到页面里**所有**
      // 滚动视图冒泡上来的通知，拖一下更新历列表标题栏就糊上了，往回拖又
      // 消失。进度机制已随全程模糊删除，这里防的是有人把它加回来时重蹈
      // 覆辙 —— 无论嵌套列表怎么滚，玻璃都该稳稳地在那儿。
      Widget nestedPage() => MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            home: ImmersiveScaffold(
              title: '动态课程表',
              body: ListView(
                children: [
                  // 数据更新历：定高 + 内层纵向滚动
                  SizedBox(
                    height: 240,
                    child: SingleChildScrollView(
                      key: const Key('changelog-list'),
                      child: Column(
                        children: [
                          for (var i = 0; i < 30; i++)
                            SizedBox(height: 40, child: Text('更新 $i')),
                        ],
                      ),
                    ),
                  ),
                  // 课程表：横向滚动
                  SizedBox(
                    height: 120,
                    child: SingleChildScrollView(
                      key: const Key('grid-horizontal'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < 30; i++)
                            SizedBox(
                                width: 100, height: 120, child: Text('格 $i')),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 300),
                ],
              ),
            ),
          );

      await tester.pumpWidget(nestedPage());
      expect(find.byType(BackdropFilter), showsBlur);

      // ① 拖更新历内层列表：玻璃照常在
      await tester
          .drag(find.byKey(const Key('changelog-list')), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), showsBlur,
          reason: '拖更新历列表不该影响标题栏玻璃');

      // ② 横向拖课程表：同理
      await tester.drag(
          find.byKey(const Key('grid-horizontal')), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), showsBlur,
          reason: '横向拖网格不该影响标题栏玻璃');
    });

    testWidgets('关掉穿透时退回普通布局：内容从标题栏下沿开始', (tester) async {
      await tester.pumpWidget(page(extendBodyBehindAppBar: false));

      expect(
        tester.getTopLeft(find.byKey(const Key('page-body'))).dy,
        kToolbarHeight,
      );
      // Scaffold 挂 appBar 时会清掉 body 的 padding.top，所以首屏内容
      // 正好贴着标题栏下沿（不会再多一段留白）
      expect(
        tester.getTopLeft(find.text('第 0 行')).dy,
        greaterThanOrEqualTo(kToolbarHeight),
      );
      expect(tester.getTopLeft(find.text('第 0 行')).dy, lessThan(kToolbarHeight * 2));
    });

    testWidgets('点菜单打开抽屉', (tester) async {
      await tester.pumpWidget(page(drawer: const Drawer(child: Text('抽屉内容'))));

      await tester.tap(find.byKey(kImmersiveMenuKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('抽屉内容'), findsOneWidget);
    });

    testWidgets('滚动后玻璃保持常驻（不随页面滚动消失）', (tester) async {
      await tester.pumpWidget(page());

      await tester.drag(find.text('第 0 行'), const Offset(0, -240));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), showsBlur);
      expect(find.byKey(kImmersiveHighlightKey), findsOneWidget);
    });

    testWidgets('body 换实例后玻璃照常常驻（历史回归）', (tester) async {
      // 进度机制时代，body 换实例会把标题栏「收回贴顶态」。全程模糊后
      // 没有进度可重置，切页面玻璃直接就是铺好的。
      await tester.pumpWidget(page());

      await tester.drag(find.text('第 0 行'), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), showsBlur);

      // 换一个 body 实例（模拟 Shell 切换子路由）
      await tester.pumpWidget(page(bodyKey: const Key('page-body-2')));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), showsBlur,
          reason: '全程模糊下，换 body 后玻璃该原样铺着');
    });
  });
}
