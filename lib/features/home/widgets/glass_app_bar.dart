import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 网页版（yiyu14.top / Firefly 导航栏 semifull 模式）同款的「光感沉浸」标题栏。
///
/// 网页版配方（`src/styles/navbar.css` + `components/layout/Navbar.astro`）：
///
/// - **顶部态**：完全透明 —— 无背景、无模糊、无阴影、无边框，
///   页面内容直接穿透到标题栏与状态栏之下；
/// - **滚动态**（滚动超过 50px）：`card-bg` 45% 不透明度底色 +
///   `backdrop-filter: blur(20px)`，叠加两条 **box-shadow 细线**：
///   顶部内高光（亮色 rgba(255,255,255,.18) / 暗色 rgba(255,255,255,.06)）
///   与底部分发丝线（亮色 rgba(0,0,0,.06) / 暗色 rgba(255,255,255,.10)）——
///   是阴影不是 border，所以「无边框」；
/// - **过渡**：0.36s `cubic-bezier(0.22, 1, 0.36, 1)`（与 Flutter
///   [Curves.easeOutQuint] 完全一致），模糊渐显渐隐；
/// - **滚动监听**：网页版用 scroll + rAF 节流；Flutter 的
///   [ScrollNotification] 本身就是帧驱动的，直接换算即可。
///
/// 性能：模糊**不跟手**。进度先二值化（滚过 50px 即 1，否则 0），
/// 模糊由一次 360ms 渐变动画完成 —— BackdropFilter 每帧 readback
/// 在真机上很卡，只让它动个位数的帧次。
///
/// 用法：
/// ```dart
/// appBar: glassAppBar(title: '动态课程表', progress: t, onMenu: openDrawer)
/// ```
class GlassAppBarLayer extends StatelessWidget {
  const GlassAppBarLayer({
    super.key,
    required this.title,
    this.progress = 0,
  });

  /// 标题文字。
  final String title;

  /// 折叠进度：0 = 贴顶（全透明），1 = 滚过阈值（毛玻璃）。
  /// 由 [glassProgressOf] 二值化产出。
  final double progress;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final t = progress.clamp(0.0, 1.0);

    // 顶部内高光 / 底部分发丝线（网页版 --navbar-glass-highlight / -hairline）
    final highlightColor =
        isDark ? const Color(0x0FFFFFFF) : const Color(0x2EFFFFFF); // .06 / .18
    final hairlineColor =
        isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000); // .10 / .06

    final titleStyle = TextStyle(
      color: scheme.onSurface,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    );

    // 贴顶态整层不渲染（网页版 semifull static 也是全透明），
    // 连 readback 都不发生；过渡与滚动态才铺材质。
    if (t <= 0.01) {
      return Padding(
        padding: EdgeInsets.only(top: top),
        child: Row(
          children: [
            const SizedBox(width: 48), // 避开 AppBar leading 菜单按钮
            Expanded(
              child: Text(
                title,
                key: const Key('glass-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
          ],
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: t),
      duration: const Duration(milliseconds: 360),
      curve: const Cubic(0.22, 1, 0.36, 1), // == 网页版的过渡曲线
      builder: (context, v, _) {
        final sigma = ui.lerpDouble(0, 20, v)!; // 网页版 blur = 20px
        final bgAlpha = ui.lerpDouble(0, 0.45, v)!; // 网页版 card-bg 45%

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

            // ② 材质底色：card-bg 45%（网页版 color-mix 45%）
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: scheme.surface.withValues(alpha: bgAlpha),
                ),
              ),
            ),

            // ③ 顶部内高光细线（网页版 inset 0 1px 0）
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 1,
              child: IgnorePointer(
                child: Opacity(
                  opacity: v,
                  child: ColoredBox(
                    key: const Key('glass-highlight'),
                    color: highlightColor,
                  ),
                ),
              ),
            ),

            // ④ 底部分发丝线（网页版 0 1px 0）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 1,
              child: IgnorePointer(
                child: Opacity(
                  opacity: v,
                  child: ColoredBox(
                    key: const Key('glass-hairline'),
                    color: hairlineColor,
                  ),
                ),
              ),
            ),

            // ⑤ 标题（固定一行，网页版 navbar 标题同样不折叠）
            Padding(
              padding: EdgeInsets.only(top: top),
              child: Row(
                children: [
                  const SizedBox(width: 48), // 避开 AppBar leading 菜单按钮
                  Expanded(
                    child: Text(
                      title,
                      key: const Key('glass-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 网页版 semifull 的滚动阈值：`scrollTop > 50` 才进入 scrolled 态。
const double kGlassScrollThreshold = 50;

/// 把页面滚动距离二值化为标题栏折叠进度（对齐网页版 `scrollTop > 50`）。
///
/// 没有可滚动内容（maxScrollExtent <= 0）时恒为 0（贴顶）。
double glassProgressOf(ScrollMetrics metrics) {
  final max = metrics.maxScrollExtent;
  if (!metrics.hasContentDimensions || max <= 0) return 0;
  return metrics.pixels > kGlassScrollThreshold ? 1 : 0;
}

/// 组装网页版同款「光感沉浸」标题栏。
///
/// - [title]：页名；
/// - [progress]：折叠进度的可监听源，见 [glassProgressOf]；
/// - [onMenu]：左上角菜单按钮回调。
///
/// 内部用 [ValueListenableBuilder] 只重建 flexibleSpace 层，
/// 切换时不动 AppBar 本体（Scaffold.appBar 要求 PreferredSizeWidget）。
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
