import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/widgets/immersive_app_bar.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

/// 把「模糊层对不对」钉在**真实光栅化结果**上。
///
/// 结构断言（比如「铺了 N 个 BackdropFilter」）只能证明代码跑到了那一步，
/// 证明不了「铺了但没糊」「糊到了标题栏外面」。这里改成：内容放一条竖直
/// 黑白硬边，取图后逐行量这条边的**过渡宽度** —— 越糊越宽、一刀切为 0。
///
/// 于是三条不变量都能直接量出来：
///   ① 条内自上而下越来越清（单调不增）；
///   ② 贴着标题栏下沿必须已经几乎不糊；
///   ③ 条外必须是 0（一旦 > 0 就是「整页糊」的回归）。
///
/// 原生（`flutter test`）与 Web（`--platform chrome`）跑同一套断言。
/// **别再给 Web 开后门** —— 2026-10-17 就是因为按平台把 Web 的模糊整个
/// 关掉了，才出现「逐渐模糊没效果」。
void main() {
  /// 某一行上硬边的过渡宽度（px）：从接近亮端跨到接近暗端有多远。
  ///
  /// 返回 null = 这一行没有足够对比度（内容没铺到这儿），不算数。
  ///
  /// 窗口取 x ∈ [300, 580)：**必须避开标题栏自己的图标和标题文字**
  /// （左起 ~56px 是菜单键、其后是标题，测试环境没有真字体、字形会渲染成
  /// 实心色块，压进窗口里会被误判成「糊了」）。所以硬边放在 x=400。
  int? edgeWidth(Uint8List rgba, int width, int y,
      {int x0 = 300, int x1 = 580}) {
    var hi = 0, lo = 255;
    for (var x = x0; x < x1; x++) {
      final v = rgba[(y * width + x) * 4];
      if (v > hi) hi = v;
      if (v < lo) lo = v;
    }
    if (hi - lo < 40) return null;
    final tHi = lo + 0.9 * (hi - lo);
    final tLo = lo + 0.1 * (hi - lo);
    int? a, b;
    for (var x = x0; x < x1; x++) {
      final v = rgba[(y * width + x) * 4];
      a ??= v <= tHi ? x : null;
      b ??= v <= tLo ? x : null;
    }
    if (a == null || b == null) return null;
    return (b - a).abs();
  }

  testWidgets('滚动态：模糊从下到上逐渐增强，且一点都没糊到标题栏外面', (tester) async {
    const statusBar = 60.0;
    const barHeight = 116; // = statusBar + kToolbarHeight（60 + 56）
    expect(barHeight, statusBar + kToolbarHeight);

    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: statusBar);
    addTearDown(tester.view.reset);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(useMaterial3: true),
          home: ImmersiveScaffold(
            title: '动态课程表',
            body: ListView(
              // 写死 zero：内容从 y=0 起（标题栏底下），硬边才穿得过去
              padding: EdgeInsets.zero,
              children: const [
                SizedBox(
                  height: 1200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 硬边落在 x=400：为了躲开标题栏左侧的图标 / 标题字形
                      SizedBox(
                          width: 400, child: ColoredBox(color: Colors.white)),
                      Expanded(child: ColoredBox(color: Colors.black)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    /// 取图并摊成 RGBA。取图 / 编码走真异步，必须包在 runAsync 里，
    /// 否则 testWidgets 的假异步不会推进它，直接 await 会挂死。
    Future<(Uint8List, int)> grab() async {
      late final Uint8List bytes;
      late final int width;
      await tester.runAsync(() async {
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        width = image.width;
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        bytes = data!.buffer.asUint8List();
      });
      return (bytes, width);
    }

    // ── 贴顶态：整条都不该有模糊（连模糊层都不铺）────────────────────
    var (rgba, width) = await grab();
    for (var y = 8; y < barHeight - 4; y += 8) {
      final w = edgeWidth(rgba, width, y);
      expect(w, anyOf(isNull, 0),
          reason: '贴顶态 y=$y 处不该有模糊，实测过渡宽度 $w');
    }

    // ── 滚过阈值：材质渐显 ────────────────────────────────────────────
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(kImmersiveScrollThreshold + 60);
    await tester.pumpAndSettle(); // 等 360ms 渐变走完

    (rgba, width) = await grab();

    // ① 条内：自上而下单调变清（容差 2px 吸收分带边界的抖动）
    int? prev;
    for (var y = 8; y < barHeight - 6; y += 4) {
      final w = edgeWidth(rgba, width, y);
      expect(w, isNotNull, reason: '条内 y=$y 应该有可测的硬边');
      if (prev != null) {
        expect(w!, lessThanOrEqualTo(prev + 2),
            reason: 'y=$y 的模糊不该比上一行更重（$w > $prev）');
      }
      prev = w;
    }

    // ② 顶部满糊、贴着下沿已几乎不糊
    final top = edgeWidth(rgba, width, 8)!;
    final bottom = edgeWidth(rgba, width, barHeight - 6)!;
    expect(top, greaterThanOrEqualTo(25), reason: '顶部该是满糊');
    expect(bottom, lessThanOrEqualTo(4), reason: '标题栏下沿该基本不糊');
    expect(top, greaterThan(bottom + 15), reason: '上下差别要看得出来');

    // ③ 条外：必须一刀切。这里一旦出现扩散，就是「整页糊」回归了。
    for (final y in [barHeight + 8, barHeight + 40, barHeight + 120]) {
      expect(edgeWidth(rgba, width, y), 0,
          reason: '标题栏外面（y=$y）必须是清晰的一刀切');
    }
  });
}
