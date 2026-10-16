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
  ///
  /// 原生后端上模糊层是**一叠横带**（渐进模糊），所以不是「有 1 个」而是「有一组」。
  /// 测试视口里没有状态栏内边距，标题栏正好 [kToolbarHeight] 高。
  final Matcher showsBlur = ImmersiveGlassLayer.blurSupported
      ? findsAtLeastNWidgets(immersiveBlurBands(kToolbarHeight).length)
      : findsNothing;

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

  /// 取材质底色渐变的两个端点透明度（顶部、底部）。
  List<double> tintAlphas(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(find.byKey(kImmersiveTintKey));
    final gradient = (box.decoration as BoxDecoration).gradient! as LinearGradient;
    return [for (final c in gradient.colors) c.a];
  }

  /// 取当前所有模糊横带的位置（按自上而下的绘制顺序）。
  List<Rect> bandRects(WidgetTester tester) {
    final finder = find.byType(BackdropFilter);
    final n = tester.widgetList(finder).length;
    return [for (var i = 0; i < n; i++) tester.getRect(finder.at(i))];
  }

  // ── 渐进模糊分带 ──────────────────────────────────────────────────────
  group('immersiveBlurBands 渐进分带', () {
    test('顶部最糊、底部趋近 0，自上而下单调递减', () {
      final bands = immersiveBlurBands(103);

      // 顶上那几条都在「怎么看都一样糊」的门槛之上
      expect(bands.first.sigma, greaterThan(kImmersiveBlurKnee));
      expect(bands.last.sigma, lessThan(1));
      for (var i = 1; i < bands.length; i++) {
        expect(bands[i].sigma, lessThan(bands[i - 1].sigma));
      }
    });

    test('横带严丝合缝盖满整条标题栏（不重叠、不留缝）', () {
      for (final height in <double>[56, 103, 103.5, 240]) {
        final bands = immersiveBlurBands(height);

        expect(bands.first.top, 0, reason: 'height=$height');
        expect(bands.last.top + bands.last.height, height,
            reason: 'height=$height');
        for (var i = 0; i < bands.length; i++) {
          expect(bands[i].height, greaterThan(0), reason: 'height=$height');
          if (i > 0) {
            expect(bands[i].top, bands[i - 1].top + bands[i - 1].height,
                reason: 'height=$height');
          }
        }
      }
    });

    test('「反正都是糊」的那一段不切碎：带上宽下窄，条数只有硬切的一半', () {
      final bands = immersiveBlurBands(103);

      expect(bands.first.height, greaterThan(bands.last.height));
      // 等 σ 步长硬切要 20 条（20/1），这里靠粗段压到 10 条上下 ——
      // 每条带一次模糊，少一半就是每帧少一半开销。
      expect(bands.length, lessThanOrEqualTo(12));
      expect(bands.length, greaterThanOrEqualTo(8));
    });

    test('带数只看「占整条多少」，与标题栏高度无关', () {
      expect(immersiveBlurBands(56).length, immersiveBlurBands(206).length);
    });

    test('拿不到有限高度就不分带（宁可没模糊，也不糊全屏）', () {
      expect(immersiveBlurBands(0), isEmpty);
      expect(immersiveBlurBands(double.infinity), isEmpty);
    });
  });

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
        expect(find.byType(BackdropFilter), showsBlur);
      } else {
        expect(find.byType(BackdropFilter), findsNothing);
        // 观感不能塌：底色与两条细线仍在
        expect(find.byKey(kImmersiveTintKey), findsOneWidget);
        expect(find.byKey(kImmersiveHighlightKey), findsOneWidget);
        expect(find.byKey(kImmersiveHairlineKey), findsOneWidget);
      }
    });

    testWidgets('模糊层是一叠横带，只盖满标题栏、不糊全屏', (tester) async {
      // 回归：AppBar.flexibleSpace 挂在 OverflowBox(maxHeight: infinity) 下，
      // 不限高时 BackdropFilter 会被撑到全屏 → 用户看到「全屏模糊」。
      // 现在模糊层是若干条带，同样必须严格贴在这条标题栏的高度里。
      await tester.pumpWidget(wrap(bar(1)));
      await tester.pumpAndSettle();

      if (!ImmersiveGlassLayer.blurSupported) return; // Web 上压根没有模糊层

      final rects = bandRects(tester);
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(rects.length, immersiveBlurBands(kToolbarHeight).length);
      expect(rects.first.top, 0); // 顶上那条贴屏幕最上沿
      expect(rects.last.bottom, kToolbarHeight); // 底下那条到标题栏下沿为止
      expect(kToolbarHeight, lessThan(screenHeight)); // 就是没糊到全屏
      for (var i = 0; i < rects.length; i++) {
        expect(rects[i].height, greaterThan(0));
        // 相邻两条首尾相接：不重叠（模糊会叠一层）、不留缝（会露出没糊的一线）
        if (i > 0) expect(rects[i].top, rects[i - 1].bottom);
      }
    });

    testWidgets('底色上下渐变：顶部最浓、底部淡出（下沿不留硬边）', (tester) async {
      await tester.pumpWidget(wrap(bar(1)));
      await tester.pumpAndSettle();

      final alphas = tintAlphas(tester);
      if (ImmersiveGlassLayer.blurSupported) {
        // 有模糊：底色跟着模糊一起淡，底下那截才不会留下一条硬边
        expect(alphas.first, closeTo(kImmersiveTintTop, 0.001));
        expect(alphas.last, closeTo(kImmersiveTintBottom, 0.001));
        expect(alphas.first, greaterThan(alphas.last));
      } else {
        // Web 没有模糊，底色是唯一的分隔手段，必须维持接近纯色
        expect(alphas.first, closeTo(kImmersiveTintTopNoBlur, 0.001));
        expect(alphas.last, closeTo(kImmersiveTintBottomNoBlur, 0.001));
        expect(alphas.first, closeTo(alphas.last, 0.001));
      }
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

    testWidgets('渲染标题栏与内容', (tester) async {
      await tester.pumpWidget(page());

      expect(find.text('待办'), findsOneWidget);
      expect(find.text('第 0 行'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
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

      // 只滚 60px：首行仍半露在视口里（不会被 SliverList 回收），
      // 但已经进入标题栏那条带；同时 60 > 50px 阈值，玻璃该出现了。
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

    testWidgets('滚动超过阈值后标题栏渐显毛玻璃', (tester) async {
      await tester.pumpWidget(page());

      await tester.drag(find.text('第 0 行'), const Offset(0, -240));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), showsBlur);
      expect(find.byKey(kImmersiveHairlineKey), findsOneWidget);
    });

    testWidgets('body 换实例后标题栏收回贴顶态', (tester) async {
      await tester.pumpWidget(page());

      await tester.drag(find.text('第 0 行'), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), showsBlur);

      // 换一个 body 实例（模拟 Shell 切换子路由）
      await tester.pumpWidget(page(bodyKey: const Key('page-body-2')));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
