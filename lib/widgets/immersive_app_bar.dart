import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 「光感沉浸」标题栏 —— 公共组件
//
// 对照网页版 yiyu14.top（Firefly 主题导航栏 semifull 模式，
// `src/styles/navbar.css` + `src/components/layout/Navbar.astro`）逐条实现：
//
//   · 贴顶态：完全透明 —— 无背景、无模糊、无阴影、无边框；
//   · 滚动态（滚动超过 50px）：`card-bg` 45% 底色 + `blur(20px)`，
//     叠加两条 **box-shadow 细线**（顶部内高光 + 底部分发丝线），是阴影不是 border；
//   · 过渡：0.36s `cubic-bezier(0.22, 1, 0.36, 1)`，模糊渐显渐隐。
//
// 两种用法（任选）：
//   1. `ImmersiveScaffold` —— 整页交给它，自带 Scaffold / 抽屉 / 滚动监听，最省事；
//   2. `ImmersiveAppBar`  —— 只想换个标题栏，自己管 Scaffold，把它塞进 appBar 槽。
//
// 性能：模糊**不跟手**。滚动进度先二值化（滚过 50px 即 1，否则 0），
// 模糊由一次 [kImmersiveTransition] 渐变动画完成 —— BackdropFilter 每帧
// readback 在真机上很卡，只让它动个位数的帧次。
// ─────────────────────────────────────────────────────────────────────────────

/// 进入滚动态的滚动阈值，对齐网页版 `scrollTop > 50`。
const double kImmersiveScrollThreshold = 50;

/// 材质渐显 / 渐隐时长，对齐网页版 `--navbar-surface-transition: .36s`。
const Duration kImmersiveTransition = Duration(milliseconds: 360);

/// 过渡曲线，与网页版 `cubic-bezier(0.22, 1, 0.36, 1)` 完全一致。
const Cubic kImmersiveCurve = Cubic(0.22, 1, 0.36, 1);

/// 标题文字 Key（贴顶 / 滚动两态共用同一条标题）。
const Key kImmersiveTitleKey = Key('immersive-title');

/// 左上角菜单按钮 Key。
const Key kImmersiveMenuKey = Key('immersive-menu');

/// 顶部内高光细线 Key。
const Key kImmersiveHighlightKey = Key('immersive-highlight');

/// 底部分发丝线 Key。
const Key kImmersiveHairlineKey = Key('immersive-hairline');

/// 把页面滚动距离二值化为标题栏折叠进度（对齐网页版 `scrollTop > 50`）。
///
/// 没有可滚动内容（`maxScrollExtent <= 0`）时恒为 0（贴顶）。
double immersiveProgressOf(ScrollMetrics metrics) {
  final max = metrics.maxScrollExtent;
  if (!metrics.hasContentDimensions || max <= 0) return 0;
  return metrics.pixels > kImmersiveScrollThreshold ? 1 : 0;
}

/// 标题栏的材质层：毛玻璃 + 底色 + 两条阴影细线。
///
/// 单独抽出来是为了让任何自定义标题栏都能套同一套材质，而不必自己重算
/// 模糊 / 底色 / 细线。**父级高度必须是有限值**：内部用 [Positioned.fill]
/// 铺满父级，父级高度即模糊层高度（否则 BackdropFilter 会被撑到全屏）。
///
/// 自绘标题栏时把它铺在底层即可：
/// ```dart
/// Stack(children: [
///   Positioned.fill(child: ImmersiveGlassLayer(progress: t)),
///   /* 你自己的标题栏内容 */
/// ]);
/// ```
class ImmersiveGlassLayer extends StatelessWidget {
  const ImmersiveGlassLayer({
    super.key,
    required this.progress,
    this.blur,
  });

  /// 折叠进度：0 = 贴顶（全透明），1 = 滚过阈值（毛玻璃）。
  /// 通常由 [immersiveProgressOf] 二值化产出。
  final double progress;

  /// 是否启用毛玻璃。默认 [blurSupported]。
  ///
  /// 需要「看着像但不要真模糊」的场合（例如跑在不支持 BackdropFilter
  /// 的渲染后端上做截图回归）可以显式关掉，此时退化为加浓底色。
  final bool? blur;

  /// 当前后端是否支持毛玻璃。
  ///
  /// **Flutter Web 上为 false**：Web 引擎画 BackdropFilter 时不对图层做
  /// 裁剪，滤镜会作用到整张 backdrop，导致「整页糊成一片」（引擎已知缺陷，
  /// flutter/flutter#48450）。Web 上因此退化为「加浓底色 + 两条细线」，
  /// 观感接近但不发散发模糊；Android / iOS / macOS 走完整配方。
  static const bool blurSupported = !kIsWeb;

  bool get _blurred => blur ?? blurSupported;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    // 顶部内高光 / 底部分发丝线（网页版 --navbar-glass-highlight / -hairline）
    final highlightColor =
        isDark ? const Color(0x0FFFFFFF) : const Color(0x2EFFFFFF); // .06 / .18
    final hairlineColor =
        isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000); // .10 / .06

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: kImmersiveTransition,
      curve: kImmersiveCurve,
      builder: (context, v, _) {
        // 贴顶态整层不铺（网页版 semifull static 也是全透明），
        // 连 readback 都不发生。
        if (v <= 0.01) return const SizedBox.expand();

        final sigma = _blurred ? ui.lerpDouble(0, 20, v)! : 0.0; // 网页版 blur 20px
        // Web 上没有模糊，靠加浓底色把标题栏与内容分开
        final bgAlpha = ui.lerpDouble(0, _blurred ? 0.45 : 0.72, v)!;

        return Stack(
          fit: StackFit.expand,
          children: [
            // ① 毛玻璃：模糊穿透到标题栏之下的内容（ClipRect 保证只作用于本层）
            if (sigma > 0.01)
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                ),
              ),

            // ② 材质底色：card-bg 45%（网页版 color-mix 45%）
            ColoredBox(color: scheme.surface.withValues(alpha: bgAlpha)),

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
                    key: kImmersiveHighlightKey,
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
                    key: kImmersiveHairlineKey,
                    color: hairlineColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
