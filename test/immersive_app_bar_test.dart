import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/widgets/immersive_app_bar.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

/// 只覆写 immersiveProgressOf 用得到的几个成员，其余走 noSuchMethod。
class _FakeMetrics implements ScrollMetrics {
  const _FakeMetrics(this.pixels, this._max, {this.hasContentDimensions = true});

  @override
  final double pixels;

  final double _max;

  @override
  final bool hasContentDimensions;

  @override
  double get maxScrollExtent => _max;

  @override
  double get minScrollExtent => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => 0.0;
}

void main() {
  /// 当前后端是否该有毛玻璃层。
  ///
  /// Web（`flutter test --platform chrome`）上 [ImmersiveGlassLayer.blurSupported]
  /// 为 false —— 引擎不裁剪 BackdropFilter 的图层，滤镜会糊满整页。
  final Matcher showsBlur =
      ImmersiveGlassLayer.blurSupported ? findsOneWidget : findsNothing;

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

  ImmersiveAppBar bar(
    double progress, {
    VoidCallback? onMenu,
    ValueNotifier<double>? source,
    Widget? leading,
  }) =>
      ImmersiveAppBar(
        title: '动态课程表',
        progress: source ?? ValueNotifier<double>(progress),
        onMenu: onMenu,
        leading: leading,
      );

  double opacityOf(WidgetTester tester, Key key) {
    final opacity = tester.widget<Opacity>(find.ancestor(
      of: find.byKey(key),
      matching: find.byType(Opacity),
    ));
    return opacity.opacity;
  }

  // ── 进度换算 ──────────────────────────────────────────────────────────
  group('immersiveProgressOf 滚动阈值', () {
    test('按网页版 50px 阈值二值化', () {
      double progress(double pixels, {double max = 1000, bool dims = true}) =>
          immersiveProgressOf(_FakeMetrics(pixels, max, hasContentDimensions: dims));

      expect(progress(0), 0);
      expect(progress(-30), 0); // 过滚动（overscroll）不为负
      expect(progress(49), 0);
      expect(progress(50), 0); // 网页版是 scrollTop > 50，等于 50 仍算贴顶
      expect(progress(51), 1);
      expect(progress(500), 1); // 封顶 1
    });

    test('无滚动内容时恒为 0', () {
      expect(immersiveProgressOf(const _FakeMetrics(100, 0)), 0);
      expect(
        immersiveProgressOf(const _FakeMetrics(100, 800, hasContentDimensions: false)),
        0,
      );
    });
  });

  // ── ImmersiveAppBar ──────────────────────────────────────────────────
  group('ImmersiveAppBar', () {
    testWidgets('贴顶态：整层全透明（无模糊 / 无底色 / 无细线）', (tester) async {
      await tester.pumpWidget(wrap(bar(0)));

      expect(find.byKey(kImmersiveTitleKey), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byKey(kImmersiveHighlightKey), findsNothing);
      expect(find.byKey(kImmersiveHairlineKey), findsNothing);
    });

    testWidgets('滚动态：渐显毛玻璃 + 两条阴影细线', (tester) async {
      await tester.pumpWidget(wrap(bar(1)));
      await tester.pumpAndSettle(); // 等 360ms 渐变动画走完

      expect(find.byType(BackdropFilter), showsBlur);
      expect(find.byKey(kImmersiveHighlightKey), findsOneWidget);
      expect(find.byKey(kImmersiveHairlineKey), findsOneWidget);
      expect(opacityOf(tester, kImmersiveHighlightKey), 1.0);
      expect(opacityOf(tester, kImmersiveHairlineKey), 1.0);
    });

    testWidgets('Web 后端不铺 BackdropFilter（否则会糊满整页）', (tester) async {
      // Web 引擎画 BackdropFilter 时不对图层做裁剪，滤镜作用到整张 backdrop
      // → 用户看到「整页糊成一片」。所以 Web 上直接不铺模糊层，
      // 退化为「加浓底色 + 两条细线」，观感接近。
      await tester.pumpWidget(wrap(bar(1)));
      await tester.pumpAndSettle();

      if (ImmersiveGlassLayer.blurSupported) {
        expect(find.byType(BackdropFilter), findsOneWidget);
      } else {
        expect(find.byType(BackdropFilter), findsNothing);
        // 观感不能塌：底色与两条细线仍在
        expect(find.byKey(kImmersiveHighlightKey), findsOneWidget);
        expect(find.byKey(kImmersiveHairlineKey), findsOneWidget);
      }
    });

    testWidgets('模糊层只覆盖标题栏高度，不糊全屏', (tester) async {
      // 回归：AppBar.flexibleSpace 挂在 OverflowBox(maxHeight: infinity) 下，
      // 不限高时 BackdropFilter 会被撑到全屏 → 用户看到「全屏模糊」。
      await tester.pumpWidget(wrap(bar(1)));
      await tester.pumpAndSettle();

      if (!ImmersiveGlassLayer.blurSupported) return; // Web 上压根没有模糊层
      final blurSize = tester.getSize(find.byType(BackdropFilter));
      expect(blurSize.height, kToolbarHeight); // 测试环境无状态栏 padding
      expect(
        blurSize.height,
        lessThan(tester.view.physicalSize.height / tester.view.devicePixelRatio),
      );
    });

    testWidgets('标题栏高度 = 工具栏行（不含状态栏内边距时）', (tester) async {
      await tester.pumpWidget(wrap(bar(1)));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(ImmersiveAppBar)).height, kToolbarHeight);
    });

    testWidgets('显式 onMenu 点击触发回调', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(bar(0, onMenu: () => tapped = true)));

      await tester.tap(find.byKey(kImmersiveMenuKey));
      expect(tapped, isTrue);
    });

    testWidgets('不传 onMenu 时点菜单打开 Scaffold 抽屉（默认行为）', (tester) async {
      // 回归：曾在创建 Scaffold 的那个 context 上调 Scaffold.of，
      // 抛「Scaffold.of() called with a context that does not contain a Scaffold」。
      // 现在菜单动作走标题栏自身（Scaffold 之下）的 context。
      await tester.pumpWidget(
        wrap(bar(0), drawer: const Drawer(child: Text('抽屉内容'))),
      );

      await tester.tap(find.byKey(kImmersiveMenuKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('抽屉内容'), findsOneWidget);
    });

    testWidgets('没有抽屉、没有 onMenu、不能返回时不放任何左侧按钮', (tester) async {
      await tester.pumpWidget(wrap(bar(0)));

      expect(find.byKey(kImmersiveMenuKey), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('显式 leading 覆盖默认左侧按钮', (tester) async {
      await tester.pumpWidget(
        wrap(bar(0, onMenu: () {}, leading: const Icon(Icons.star))),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byKey(kImmersiveMenuKey), findsNothing);
    });

    testWidgets('进度源更新后标题栏跟随刷新（整页骨架的接入方式）', (tester) async {
      final progress = ValueNotifier<double>(0);
      await tester.pumpWidget(wrap(bar(0, source: progress)));

      expect(find.byType(BackdropFilter), findsNothing);

      progress.value = 1;
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), showsBlur);
      expect(find.byKey(kImmersiveHairlineKey), findsOneWidget);

      // 收回贴顶：整层材质消失
      progress.value = 0;
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byKey(kImmersiveHairlineKey), findsNothing);
    });

    testWidgets('深色主题正常渲染', (tester) async {
      await tester.pumpWidget(wrap(bar(1), brightness: Brightness.dark));
      await tester.pumpAndSettle();

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
    }) {
      return MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: ImmersiveScaffold(
          title: title,
          drawer: drawer,
          body: ListView.builder(
            key: bodyKey,
            itemCount: 80,
            itemBuilder: (context, i) =>
                SizedBox(height: 60, child: Text('第 $i 行')),
          ),
        ),
      );
    }

    testWidgets('渲染标题栏与内容', (tester) async {
      await tester.pumpWidget(page());

      expect(find.text('待办'), findsOneWidget);
      expect(find.text('第 0 行'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('内容从标题栏下沿开始（默认不穿透）', (tester) async {
      await tester.pumpWidget(page());

      expect(
        tester.getTopLeft(find.byKey(const Key('page-body'))).dy,
        kToolbarHeight,
      );
    });

    testWidgets('点菜单打开抽屉', (tester) async {
      await tester.pumpWidget(page(drawer: const Drawer(child: Text('抽屉内容'))));

      await tester.tap(find.byKey(kImmersiveMenuKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('抽屉内容'), findsOneWidget);
    });

    testWidgets('滚动超过阈值后标题栏渐显毛玻璃', (tester) async {
      await tester.pumpWidget(page());

      await tester.drag(find.byKey(const Key('page-body')), const Offset(0, -240));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), showsBlur);
      expect(find.byKey(kImmersiveHairlineKey), findsOneWidget);
    });

    testWidgets('body 换实例后标题栏收回贴顶态', (tester) async {
      await tester.pumpWidget(page());

      await tester.drag(find.byKey(const Key('page-body')), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), showsBlur);

      // 换一个 body 实例（模拟 Shell 切换子路由）
      await tester.pumpWidget(page(bodyKey: const Key('page-body-2')));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
