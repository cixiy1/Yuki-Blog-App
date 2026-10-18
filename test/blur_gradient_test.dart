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
  /// 某一行上硬边的过渡宽度（px，亚像素精度）：从 90% 亮端跨到 10% 暗端。
  ///
  /// 返回 null = 这一行没有足够对比度（内容没铺到这儿），不算数。
  ///
  /// 用线性插值找阈值穿越点，而不是数整数像素：低 σ 段的过渡只有十来像素，
  /// 整数量化误差能到 ±1px，而相邻两带的真实差距只有 2.56·Δσ ≈ 2.5px ——
  /// 不插值就等于在噪声里找信号。
  ///
  /// 清晰的一刀切在这里约等于 0.8（穿越点落在相邻两个像素之间），
  /// 所以「有没有糊」的判据是 > 2 左右，很好区分。
  ///
  /// 窗口取 x ∈ [300, 580)：**必须避开标题栏自己的图标和标题文字**
  /// （左起 ~56px 是菜单键、其后是标题，测试环境没有真字体、字形会渲染成
  /// 实心色块，压进窗口里会被误判成「糊了」）。所以硬边放在 x=400。
  double? edgeWidth(Uint8List rgba, int width, int y,
      {int x0 = 300, int x1 = 580}) {
    int at(int x) => rgba[(y * width + x) * 4];
    var hi = 0, lo = 255;
    for (var x = x0; x < x1; x++) {
      final v = at(x);
      if (v > hi) hi = v;
      if (v < lo) lo = v;
    }
    if (hi - lo < 40) return null;
    final tHi = lo + 0.9 * (hi - lo);
    final tLo = lo + 0.1 * (hi - lo);

    /// 从左往右第一次跌破 [t] 的位置（插值到亚像素）
    double? cross(double t) {
      for (var x = x0 + 1; x < x1; x++) {
        final a = at(x - 1), b = at(x);
        if (a > t && b <= t) {
          if (a == b) return x.toDouble();
          return (x - 1) + (a - t) / (a - b);
        }
      }
      return null;
    }

    final a = cross(tHi);
    final b = cross(tLo);
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
      expect(w, anyOf(isNull, lessThan(1.5)),
          reason: '贴顶态 y=$y 处不该有模糊，实测过渡宽度 $w');
    }

    // ── 滚过阈值：材质渐显 ────────────────────────────────────────────
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(kImmersiveScrollThreshold + 60);
    await tester.pumpAndSettle(); // 等 360ms 渐变走完

    (rgba, width) = await grab();

    // ① 条内：自上而下单调变清（容差 3px 吸收测量抖动）
    double? prev;
    for (var y = 8; y < barHeight - 6; y += 4) {
      final w = edgeWidth(rgba, width, y);
      expect(w, isNotNull, reason: '条内 y=$y 应该有可测的硬边');
      if (prev != null) {
        expect(w!, lessThanOrEqualTo(prev + 3),
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
      expect(edgeWidth(rgba, width, y), lessThan(1.5),
          reason: '标题栏外面（y=$y）必须是清晰的一刀切');
    }

    // ④ 每条横带的接缝处不能「跳一下」。
    //
    // 这是「割裂感」的量化：带与带之间 σ 突变多少，相邻两条的模糊强度就差
    // 多少，眼睛看到的就是一条横线。
    //
    // 判据取「带内逐行平均」而不是「接缝上下两行相减」：单行测量抖动大，
    // 而相邻两带的真实差距只有 2.56·Δσ ≈ 2.5px —— 逐行相减等于在噪声里
    // 找信号。带内平均把抖动摊掉，剩下的是这条带真正的模糊强度。
    //
    // 阈值 8：等步长（Δσ=1）时实测 2.5~5.4（CanvasKit 与 Skia 的模糊实现
    // 略有差异；高 σ 段过渡平缓，8bit 量化在插值时被放大，所以留足余量）。
    // 而曾经 σ>8 那段用 6 的粗步长，相邻带差到 15px 上下，一眼就是横线 ——
    // 8 依然能把那次回退抓住。
    //
    // 「步长必须小」这条更精确的约束在 immersive_app_bar_test.dart 里直接对
    // σ 阶梯断言（与渲染后端无关），这里只管「渲染出来真的看不出横线」。
    final bands = immersiveBlurBands(barHeight.toDouble());
    final means = <double>[];
    for (final b in bands) {
      final rows = <double>[];
      for (var y = b.top.round() + 1; y < (b.top + b.height).round(); y++) {
        final w = edgeWidth(rgba, width, y);
        if (w != null) rows.add(w);
      }
      if (rows.isEmpty) continue;
      means.add(rows.reduce((a, b) => a + b) / rows.length);
    }
    expect(means.length, greaterThanOrEqualTo(16),
        reason: '大部分横带都该能量到（实际 ${means.length} 条）');
    for (var i = 1; i < means.length; i++) {
      expect(
        (means[i] - means[i - 1]).abs(),
        lessThanOrEqualTo(8),
        reason: '第 $i 条横带与上一条的模糊强度差太多'
            '（${means[i - 1].toStringAsFixed(1)} → ${means[i].toStringAsFixed(1)}），会看出横线',
      );
    }
  });
}
