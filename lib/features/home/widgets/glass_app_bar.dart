import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOS 风格「光感沉浸」标题栏（[glassAppBar]）。
///
/// 三段式观感，全部由滚动进度 [progress]（0 = 顶部，1 = 完全折叠）驱动：
///
/// 1. **沉浸**：顶部时背景近乎全透明，页面内容穿透到标题栏与状态栏之下；
/// 2. **光感**：随滚动渐显高斯模糊（毛玻璃材质）+ 顶部环境光渐层 +
///    底部发丝高光线，模拟 iOS 导航栏的 Liquid Glass 光泽；
/// 3. **标题**：大字标题（30px）淡出上移，小字标题（20px）淡入到工具栏行，
///    对应 iOS large title → inline title 的折叠动画。
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
    final t = progress.clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // 毛玻璃模糊：0 → 20（iOS 系统材质量级），缓出让前段更"透"
    final sigma = ui.lerpDouble(0, 20, Curves.easeOut.transform(t))!;
    // 底色不透明度：约 0 → 0.82（滚动后才"实"，保证文字可读）
    final bgAlpha = ui.lerpDouble(0.03, 0.82, t)!;
    // 底部发丝线：常驻但很淡，滚动后变实
    final lineAlpha = (0.25 + 0.65 * t).clamp(0.0, 1.0);

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

        // ③ 顶部环境光：像光从状态栏上方洒下来（"光感"的来源）
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.09 : 0.34),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ④ 底部发丝高光线：中段亮、两端渐隐
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 1,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(
                      alpha: (isDark ? 0.22 : 0.85) * lineAlpha,
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
  }
}

/// 大字 → 小字的折叠距离（像素），与 iOS large title 的折叠手感对齐。
const double kGlassCollapseRange = 72;

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
