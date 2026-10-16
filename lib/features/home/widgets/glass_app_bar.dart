import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS 风格「光感沉浸」标题栏（[glassAppBar]）。
///
/// 观感（无边框、逐渐模糊）：
///
/// 1. **沉浸**：顶部时背景近乎全透明，页面内容穿透到标题栏与状态栏之下；
/// 2. **逐渐模糊**：滚过阈值后 180ms 内渐显高斯模糊（毛玻璃材质）与材质
///    底色，叠一层顶部环境光 —— **全程没有任何线条 / 边框**；
/// 3. **标题**：大字标题（30px）淡出上移，小字（20px）淡入工具栏行，
///    对应 iOS large title → inline title 的折叠动画。
///
/// 性能：模糊**不跟手**。BackdropFilter 每帧 readback 在真机上很卡，
/// 所以滚动进度先量化为 0/1 两档（见 [_quantize]），模糊由一次 180ms
/// 渐变动画完成，整个滚动过程最多触发十几次模糊重算。
///
/// 用法（配合 [ScrollNotification] 把页面滚动进度喂进来）：
/// ```dart
/// appBar: glassAppBar(title: '动态课程表', progress: t, onMenu: openDrawer)
/// ```
class GlassAppBarLayer extends StatelessWidget {
  const GlassAppBarLayer({
    super.key,
    required this.title,
    this.progress = 0,
  });

  /// 标题文字：大字 / 小字两态共用。
  final String title;

  /// 滚动折叠进度：0 = 停在顶部，1 = 完全折叠。
  final double progress;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // 目标量化：只有「贴顶（0）」与「滚过阈值（1）」两态。
    // 模糊**不跟手**（不随滚动每帧连续变化），而是由 TweenAnimationBuilder
    // 在 180ms 内渐变过去 —— BackdropFilter 的每帧 readback 是真机卡顿
    // 的元凶，只让它动个位数的帧次。
    final target = progress >= _kGlassQuantize ? 1.0 : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        // 毛玻璃模糊：0 → 16（iOS 系统材质量级）
        final sigma = ui.lerpDouble(0, 16, t)!;
        // 底色不透明度：约 0 → 0.80（滚动后才"实"，保证文字可读）
        final bgAlpha = ui.lerpDouble(0.02, 0.80, t)!;

        final titleStyle = TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        );

        // 工具栏行（状态栏之下、kToolbarHeight 高）内左对齐的标题文字，
        // 避开 AppBar leading 菜单按钮（宽 48）。
        Widget titleAt(double fontSize, double opacity, double dy, Key key) {
          return Positioned(
            left: 48,
            right: 16,
            top: top,
            height: kToolbarHeight,
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      key: key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle.copyWith(fontSize: fontSize),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // ① 毛玻璃：模糊穿透到标题栏之下的页面内容
            if (sigma > 0.01)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                ),
              ),

            // ② 材质底色：顶部略透、底部渐实，滚动过程中整体浮现
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.surface.withValues(alpha: bgAlpha * 0.88),
                      scheme.surface.withValues(alpha: bgAlpha),
                    ],
                  ),
                ),
              ),
            ),

            // ③ 顶部环境光：像光从状态栏上方洒下来（"光感"的来源）。
            // 只是柔光渐层、没有线条，不构成边框。
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(
                          alpha: (isDark ? 0.07 : 0.22) * t,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ⑥ 大字标题：iOS large title 态，随滚动淡出上移
            titleAt(30, 1 - t, 12 * t, const Key('glass-large-title')),

            // ⑦ 小字标题：inline 态，随滚动淡入
            titleAt(20, t, 6 * (1 - t), const Key('glass-inline-title')),
          ],
        );
      },
    );
  }
}

/// 大字 → 小字的折叠距离（像素），与 iOS large title 的折叠手感对齐。
const double kGlassCollapseRange = 72;

/// 滚动进度量化阈值：超过一半折叠距离即算「滚过了」。
const double _kGlassQuantize = 0.5;

/// 组装「光感沉浸」标题栏。
///
/// - [title]：页名（大字 / 小字两态共用）；
/// - [progress]：滚动折叠进度的可监听源，见 [glassProgressOf]；
/// - [onMenu]：左上角菜单按钮回调。
///
/// 内部用 [ValueListenableBuilder] 只重建 flexibleSpace 层，
/// 滚动时不动 AppBar 本体（ Scaffold.appBar 要求 PreferredSizeWidget）。
AppBar glassAppBar({
  required String title,
  required ValueListenable<double> progress,
  required VoidCallback onMenu,
  required Brightness brightness,
}) {
  return AppBar(
    automaticallyImplyLeading: false,
    leading: Builder(
      // 用 Builder 拿到 AppBar 子树里的 context，tooltip 才挂得上
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu, size: 22),
        color: Theme.of(context).colorScheme.onSurface,
        tooltip: '菜单',
        onPressed: onMenu,
      ),
    ),
    title: null,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    // 状态栏图标明暗：沉浸态背景可能是内容本身，仍按主题底色取，
    // 保证与页面大部分区域协调。
    systemOverlayStyle: brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    flexibleSpace: ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, t, _) => GlassAppBarLayer(title: title, progress: t),
    ),
  );
}

/// 把一段页面滚动距离折算成标题栏折叠进度。
///
/// 超过 [kGlassCollapseRange] 像素即视为完全折叠；
/// 没有可滚动内容（maxScrollExtent <= 0）时恒为 0。
double glassProgressOf(ScrollMetrics metrics) {
  final max = metrics.maxScrollExtent;
  if (!metrics.hasContentDimensions || max <= 0) return 0;
  final pixels = math.max(0.0, metrics.pixels);
  return (pixels / kGlassCollapseRange).clamp(0.0, 1.0);
}
