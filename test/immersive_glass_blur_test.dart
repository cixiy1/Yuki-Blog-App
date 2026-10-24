import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/widgets/immersive_app_bar.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

/// 把「模糊层对不对」钉在**真实光栅化结果**上。
///
/// 结构断言（「铺了 N 个 BackdropFilter」）只能证明代码跑到了那一步，证明不了
/// 「铺了但没糊」「糊到了标题栏外面」。这里改成：内容放一条竖直黑白硬边，
/// 取图后逐行量这条边的**过渡宽度** —— 越糊越宽、一刀切为 0。
///
/// 于是三条不变量都能直接量出来：
///   ① 标题栏内每一行都该是满糊（σ=20）；
///   ② 整条上下一致 —— 一层、一个 σ，没有残留分带造成的强弱带；
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
  /// 用线性插值找阈值穿越点，而不是数整数像素：整数量化误差能到 ±1px，
  /// 而「有没有残留分带」要看的差异只有个位数像素 —— 不插值就等于在噪声里
  /// 找信号。
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

  testWidgets('滚动态：整条统一模糊，且一点都没糊到标题栏外面', (tester) async {
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

    // 逐行采样（跳过最顶上几行：那儿的模糊会取到状态栏区域的像素，
    // 对比度天然变低、测出来偏小，属于测量边界而不是渲染问题）
    final rows = <int, double>{};
    for (var y = 12; y <= barHeight - 8; y += 4) {
      final w = edgeWidth(rgba, width, y);
      if (w != null) rows[y] = w;
    }
    expect(rows.length, greaterThanOrEqualTo(15),
        reason: '标题栏内大部分行都该能量到硬边（实际 ${rows.length} 行）');

    final values = rows.values.toList();
    final mn = values.reduce((a, b) => a < b ? a : b);
    final mx = values.reduce((a, b) => a > b ? a : b);

    // ① 真糊了：σ=20 时硬边的 10%→90% 过渡宽度在 30px 以上（实测 40~50）
    expect(mn, greaterThanOrEqualTo(25),
        reason: '最小过渡宽度 $mn，说明有地方没糊');

    // ② 整条一致：上下任何两行都不该差出可见的量。
    //
    // 阈值 10：留足渲染后端的量化抖动（CanvasKit 与 Skia 的模糊实现略有差异，
    // 8bit 量化在插值时会被放大，实测抖动 2~4px）。而一旦有人把横切分带加
    // 回来，差 1 个 σ（≈2.5px）还能过，差到 6 个 σ（≈15px）就会挂 ——
    // 那正是用户说的「割裂」。
    expect(mx - mn, lessThanOrEqualTo(10),
        reason: '整条模糊强度不均（$mn ~ $mx），像是残留了分带');

    // ③ 条外：必须一刀切。这里一旦出现扩散，就是「整页糊」回归了。
    for (final y in [barHeight + 8, barHeight + 40, barHeight + 120]) {
      expect(edgeWidth(rgba, width, y), lessThan(1.5),
          reason: '标题栏外面（y=$y）必须是清晰的一刀切');
    }
  });
}
