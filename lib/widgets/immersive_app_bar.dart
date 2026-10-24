import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 「光感沉浸」标题栏 —— 公共组件
//
// 底子照网页版 yiyu14.top（Firefly 主题导航栏 semifull 模式，
// `src/styles/navbar.css` + `src/components/layout/Navbar.astro`）实现：
//
//   · 贴顶态：完全透明 —— 无背景、无模糊、无阴影、无边框；
//   · 滚动态（滚动超过 50px）：取主题背景色铺 45% + **整条** `blur(20px)`，
//     叠加一条 **box-shadow 细线**（顶部内高光），是阴影不是 border；
//   · 过渡：0.36s `cubic-bezier(0.22, 1, 0.36, 1)`，模糊渐显渐隐。
//
// 模糊是**整条一个强度**，与网页版 `backdrop-filter: blur(20px)` 一一对应：
// 一层半透明背景色 + 一次全幅模糊，没有第二条通道。
//
// 曾经做过「渐进模糊」——把标题栏横切成 20 条带、σ 自上而下递减到 0，让内容
// 从底下「淡出来」而不是被一刀切。观感确实更柔和，但条带之间必然留接缝
// （Δσ 每级对应约 2.5px 的扩散宽度差），实机上能看出横线；已按用户要求
// 去掉分带，改回整条统一模糊。
//
// 与网页版有一处**有意的差异**：网页版标题栏下沿还有一条发丝线（`0 1px 0`），
// App 上不画，按用户要求去掉了。
//
// 两种用法（任选）：
//   1. `ImmersiveScaffold` —— 整页交给它，自带 Scaffold / 抽屉 / 滚动监听，最省事；
//   2. `ImmersiveAppBar`  —— 只想换个标题栏，自己管 Scaffold，把它塞进 appBar 槽。
//
// 性能：模糊**不跟手**。滚动进度先二值化（滚过 50px 即 1，否则 0），
// 模糊由一次 [kImmersiveTransition] 渐变动画完成 —— BackdropFilter 每次
// readback 在真机上很卡，所以只让它动个位数的帧次，且整层只取样一次。
// ─────────────────────────────────────────────────────────────────────────────

/// 进入滚动态的滚动阈值，对齐网页版 `scrollTop > 50`。
const double kImmersiveScrollThreshold = 50;

/// 材质渐显 / 渐隐时长，对齐网页版 `--navbar-surface-transition: .36s`。
const Duration kImmersiveTransition = Duration(milliseconds: 360);

/// 过渡曲线，与网页版 `cubic-bezier(0.22, 1, 0.36, 1)` 完全一致。
const Cubic kImmersiveCurve = Cubic(0.22, 1, 0.36, 1);

/// 整条标题栏的模糊 σ，对齐网页版 `blur(20px)`。
const double kImmersiveBlurSigma = 20;

/// 材质底色的浓度：取主题背景色铺这么厚的半透明，对齐网页版 `card-bg` 45%。
///
/// 整条统一，不随高度变化 —— 模糊本身也不再渐变，底色跟着渐变就没有对应的
/// 依据了，只会让上下两截看起来像两块不同的玻璃。
const double kImmersiveTintAlpha = 0.45;

/// 标题文字 Key（贴顶 / 滚动两态共用同一条标题）。
const Key kImmersiveTitleKey = Key('immersive-title');

/// 左上角菜单按钮 Key。
const Key kImmersiveMenuKey = Key('immersive-menu');

/// 材质底色 Key（上下渐变的那个 [DecoratedBox]）。
const Key kImmersiveTintKey = Key('immersive-tint');

/// 顶部内高光细线 Key。
const Key kImmersiveHighlightKey = Key('immersive-highlight');

/// 把页面滚动距离二值化为标题栏折叠进度（对齐网页版 `scrollTop > 50`）。
///
/// 没有可滚动内容（`maxScrollExtent <= 0`）时恒为 0（贴顶）。
double immersiveProgressOf(ScrollMetrics metrics) {
  final max = metrics.maxScrollExtent;
  if (!metrics.hasContentDimensions || max <= 0) return 0;
  return metrics.pixels > kImmersiveScrollThreshold ? 1 : 0;
}

/// 标题栏的材质层：整条毛玻璃 + 一层半透明背景色 + 顶部高光细线。
///
/// 单独抽出来是为了让任何自定义标题栏都能套同一套材质，而不必自己重算
/// 模糊 / 底色 / 细线。**父级尺寸必须是有限的**：内部铺满父级，父级高度
/// 即模糊层高度（否则 BackdropFilter 会被撑到全屏）。
///
/// 自绘标题栏时把它铺在底层即可：
/// ```dart
/// Stack(children: [
///   Positioned.fill(child: ImmersiveGlassLayer(progress: t)),
///   /* 你自己的标题栏内容 */
/// ]);
/// ```
///
/// 模糊只有一层、σ 恒定（见 [kImmersiveBlurSigma]），**整条一个强度**，
/// 没有纵向渐变。想让「上糊下清」只能把标题栏横切成窄带、每条一个 σ，
/// 而条带之间必然留缝（相邻带差一个 σ 就是约 2.5px 的扩散宽度差），
/// 实机上能挑出横线 —— 已按用户要求放弃，改回整条统一模糊。
class ImmersiveGlassLayer extends StatelessWidget {
  const ImmersiveGlassLayer({
    super.key,
    required this.progress,
    this.blur = true,
  });

  /// 折叠进度：0 = 贴顶（全透明），1 = 滚过阈值（毛玻璃）。
  /// 通常由 [immersiveProgressOf] 二值化产出。
  final double progress;

  /// 是否启用毛玻璃。默认开着，四个平台一视同仁。
  ///
  /// 只有「看着像但不要真模糊」的场合才需要显式关掉（比如截图回归想要
  /// 一眼稳定的像素），关掉后退化为半透明底色 + 顶部高光线。
  ///
  /// 早先这里有个「Web 上不支持 BackdropFilter」的平台开关，**那是误判**：
  /// 当时把「flexibleSpace 无界高度把模糊层撑到全屏」和「Web 引擎不裁剪」
  /// 两个 bug 混成了一个，一刀切掉 Web 的模糊。实测（见
  /// `test/immersive_glass_blur_test.dart` 的像素断言）CanvasKit 裁剪得
  /// 好好的，Web 与 Android 的像素结果基本一致。
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 顶部内高光（网页版 --navbar-glass-highlight）。
    // 网页版还有一条底部分发丝线（--navbar-glass-hairline），这里不画：
    // 按用户要求去掉了，见文件头注释。
    final highlightColor =
        isDark ? const Color(0x0FFFFFFF) : const Color(0x2EFFFFFF); // .06 / .18

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: kImmersiveTransition,
      curve: kImmersiveCurve,
      builder: (context, v, _) {
        // 贴顶态整层不铺（网页版 semifull static 也是全透明），
        // 连 readback 都不发生。
        if (v <= 0.01) return const SizedBox.expand();

        return Stack(
          fit: StackFit.expand,
          children: [
            // ① 整条毛玻璃：一层、一个 σ
            if (blur) _glass(v),

            // ② 材质底色：取主题背景色铺 45%（网页版 color-mix 45%）
            _tint(Theme.of(context).colorScheme, v),

            // ③ 顶部内高光细线（网页版 inset 0 1px 0）
            _line(kImmersiveHighlightKey, highlightColor, v),
          ],
        );
      },
    );
  }

  /// 整条统一强度的毛玻璃。
  ///
  /// 必须自带 [ClipRect]：`BackdropFilter` 的作用范围是**当前裁剪区**，
  /// 不裁的话会糊到标题栏外面去（当年「整页模糊」的一半原因就在这儿）。
  Widget _glass(double v) {
    final sigma = kImmersiveBlurSigma * v;
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  /// 材质底色：整条铺同一层半透明背景色，对齐网页版 `card-bg` 45%。
  ///
  /// 取的是主题的 surface（明暗两套各自成立），不跟模糊一起做渐变 ——
  /// 模糊已经不分层了，底色再分层就会上下看起来像两块不同的玻璃。
  Widget _tint(ColorScheme scheme, double v) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          key: kImmersiveTintKey,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: kImmersiveTintAlpha * v),
          ),
        ),
      ),
    );
  }

  /// 顶部内高光细线（网页版 `inset 0 1px 0`），随进度渐显。
  ///
  /// 只有顶部这一条 —— 底部分发丝线按用户要求已去掉，见文件头注释。
  Widget _line(Key key, Color color, double v) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 1,
      child: IgnorePointer(
        child: Opacity(
          opacity: v,
          child: ColoredBox(
            key: key,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// 「光感沉浸」标题栏本体：材质层 + 一行标题 + 左按钮 / 右侧动作。
///
/// 自己管 Scaffold 的页面直接把它塞进 `appBar:`；整页都想省事的用
/// [ImmersiveScaffold]。
///
/// ```dart
/// Scaffold(
///   appBar: ImmersiveAppBar(
///     title: '待办',
///     progress: _progress, // ValueListenable<double>，见 immersiveProgressOf
///   ),
///   body: ...,
/// )
/// ```
///
/// 左侧按钮的取用顺序：[leading] → [onMenu] → Scaffold 自带抽屉 → 返回键
/// （[automaticallyImplyLeading]）。都没有就只留标题缩进。
class ImmersiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ImmersiveAppBar({
    super.key,
    required this.title,
    required this.progress,
    this.leading,
    this.actions,
    this.onMenu,
    this.onTitleTap,
    this.primary = true,
    this.automaticallyImplyLeading = true,
    this.toolbarHeight = kToolbarHeight,
    this.titleSpacing = 16,
  });

  /// 页名。
  final String title;

  /// 折叠进度的可监听源（0 = 贴顶，1 = 滚过阈值），见 [immersiveProgressOf]。
  /// 用 ValueNotifier 而非 setState：滚动时只重建材质层，不动整棵树。
  final ValueListenable<double> progress;

  /// 自定义左侧组件；给了它就不会再用菜单 / 返回键。
  final Widget? leading;

  /// 右侧动作区。
  final List<Widget>? actions;

  /// 菜单按钮回调。不传时：Scaffold 有抽屉则打开抽屉，否则回落返回键。
  final VoidCallback? onMenu;

  /// 标题点击回调（可选）。
  final VoidCallback? onTitleTap;

  /// 是否给状态栏留出内边距。与 `Scaffold.primary` 保持一致，默认 true。
  final bool primary;

  /// 是否自动补返回键（没有抽屉、没有 [onMenu] 时）。
  final bool automaticallyImplyLeading;

  /// 工具栏行高（不含状态栏）。
  final double toolbarHeight;

  /// 没有左侧按钮时标题左侧的缩进。
  final double titleSpacing;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = primary ? MediaQuery.paddingOf(context).top : 0.0;

    // 左侧按钮：显式 leading > onMenu > 抽屉 > 返回
    Widget? leadingWidget = leading;
    if (leadingWidget == null) {
      // 注意：这里拿到的是「Scaffold 之下」的 context（appBar 槽在
      // Scaffold 的子树里），Scaffold.maybeOf / openDrawer 都是安全的。
      // 千万别在创建 Scaffold 的那个 context 上调 Scaffold.of。
      final scaffold = Scaffold.maybeOf(context);
      if (onMenu != null) {
        leadingWidget = _iconButton(context, Icons.menu, onMenu!, '菜单',
            key: kImmersiveMenuKey);
      } else if (scaffold?.hasDrawer ?? false) {
        leadingWidget = _iconButton(
            context, Icons.menu, () => scaffold!.openDrawer(), '菜单',
            key: kImmersiveMenuKey);
      } else if (automaticallyImplyLeading) {
        final navigator = Navigator.maybeOf(context);
        if (navigator != null && navigator.canPop()) {
          leadingWidget = _iconButton(
            context,
            Icons.arrow_back,
            () => navigator.maybePop(),
            MaterialLocalizations.of(context).backButtonTooltip,
          );
        }
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 状态栏图标明暗：沉浸态背景可能是内容本身，仍按主题底色取，
      // 保证与页面大部分区域协调。
      value: theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      // 高度 = 工具栏 + 状态栏，且**有限**：材质层（含 BackdropFilter）
      // 只在这个盒子里铺开，绝不会糊到标题栏外面去。
      child: SizedBox(
        height: toolbarHeight + top,
        child: Stack(
          children: [
            // ① 材质层
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (context, t, _) => ImmersiveGlassLayer(progress: t),
              ),
            ),

            // ② 工具栏行（状态栏之下）
            Positioned(
              left: 0,
              right: 0,
              top: top,
              height: toolbarHeight,
              child: Row(
                children: [
                  if (leadingWidget != null)
                    SizedBox(
                      width: 56,
                      child: Center(child: leadingWidget),
                    )
                  else
                    SizedBox(width: titleSpacing),
                  Expanded(child: _titleWidget(scheme)),
                  ...?actions,
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleWidget(ColorScheme scheme) {
    final text = Text(
      title,
      key: kImmersiveTitleKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
    if (onTitleTap == null) return text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTitleTap,
      child: Align(alignment: Alignment.centerLeft, child: text),
    );
  }

  Widget _iconButton(
    BuildContext context,
    IconData icon,
    VoidCallback onPressed,
    String tooltip, {
    Key? key,
  }) {
    return IconButton(
      key: key,
      icon: Icon(icon, size: 22),
      color: Theme.of(context).colorScheme.onSurface,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
