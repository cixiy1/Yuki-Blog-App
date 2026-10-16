import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/features/home/widgets/glass_app_bar.dart';

/// 只覆写 glassProgressOf 用得到的几个成员，其余走 noSuchMethod。
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
  Widget wrap(PreferredSizeWidget appBar, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode:
          brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(appBar: appBar),
    );
  }

  AppBar bar(double progress, {VoidCallback? onMenu, Brightness? brightness}) =>
      glassAppBar(
        title: '动态课程表',
        progress: ValueNotifier<double>(progress),
        brightness: brightness ?? Brightness.light,
        onMenu: onMenu ?? () {},
      );

  double opacityOf(WidgetTester tester, Key key) {
    final opacity = tester.widget<Opacity>(find.ancestor(
      of: find.byKey(key),
      matching: find.byType(Opacity),
    ));
    return opacity.opacity;
  }

  testWidgets('顶部态：大字全显、小字隐藏、无毛玻璃层', (tester) async {
    await tester.pumpWidget(wrap(bar(0)));

    // 两态标题都在树里（靠 opacity 切换），文字内容一致
    expect(find.text('动态课程表'), findsNWidgets(2));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(opacityOf(tester, const Key('glass-large-title')), 1.0);
    expect(opacityOf(tester, const Key('glass-inline-title')), 0.0);
  });

  testWidgets('折叠态：小字全显、毛玻璃层出现', (tester) async {
    await tester.pumpWidget(wrap(bar(1)));

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(opacityOf(tester, const Key('glass-large-title')), 0.0);
    expect(opacityOf(tester, const Key('glass-inline-title')), 1.0);
  });

  testWidgets('中间态：两态标题都不全显（交叉淡入淡出）', (tester) async {
    await tester.pumpWidget(wrap(bar(0.5)));

    final large = opacityOf(tester, const Key('glass-large-title'));
    final inline = opacityOf(tester, const Key('glass-inline-title'));
    expect(large, closeTo(0.5, 0.001));
    expect(inline, closeTo(0.5, 0.001));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('菜单按钮点击触发回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(bar(0, onMenu: () => tapped = true)));

    await tester.tap(find.byIcon(Icons.menu));
    expect(tapped, isTrue);
  });

  testWidgets('进度源更新后标题栏跟随刷新（HomeShell 接入方式）', (tester) async {
    final progress = ValueNotifier<double>(0);
    await tester.pumpWidget(wrap(glassAppBar(
      title: '动态课程表',
      progress: progress,
      brightness: Brightness.light,
      onMenu: () {},
    )));

    expect(find.byType(BackdropFilter), findsNothing);
    expect(opacityOf(tester, const Key('glass-large-title')), 1.0);

    progress.value = 1;
    await tester.pump();

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(opacityOf(tester, const Key('glass-large-title')), 0.0);
    expect(opacityOf(tester, const Key('glass-inline-title')), 1.0);
  });

  testWidgets('深色主题正常渲染（发丝线用亮色高光）', (tester) async {
    await tester.pumpWidget(wrap(bar(0.6), brightness: Brightness.dark));

    expect(find.text('动态课程表'), findsNWidgets(2));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  test('glassProgressOf 按 72px 折叠范围折算', () {
    double progress(double pixels, {double max = 1000, bool dims = true}) =>
        glassProgressOf(_FakeMetrics(pixels, max, hasContentDimensions: dims));

    expect(progress(0), 0);
    expect(progress(-30), 0); // 过滚动（overscroll）不为负
    expect(progress(36), closeTo(0.5, 0.001));
    expect(progress(72), 1);
    expect(progress(500), 1); // 封顶 1
  });

  test('glassProgressOf 无滚动内容时恒为 0', () {
    expect(glassProgressOf(const _FakeMetrics(100, 0)), 0);
    expect(glassProgressOf(const _FakeMetrics(100, 800, hasContentDimensions: false)), 0);
  });
}
