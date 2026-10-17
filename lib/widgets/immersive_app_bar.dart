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
//   · 滚动态（滚动超过 50px）：`card-bg` 45% 底色 + `blur(20px)`，
//     叠加两条 **box-shadow 细线**（顶部内高光 + 底部分发丝线），是阴影不是 border；
//   · 过渡：0.36s `cubic-bezier(0.22, 1, 0.36, 1)`，模糊渐显渐隐。
//
// 与网页版唯一的差别是**模糊不再是一整条一个强度**：网页 `backdrop-filter`
// 也只能整条糊，而 App 上做成了**渐进模糊** —— 顶部最糊、向下线性衰减、
// 到底部趋近于零，内容是从标题栏底下「淡出来」而不是「被一刀切掉」。
// 实现方式见 [immersiveBlurBands]。
//
// 两种用法（任选）：
//   1. `ImmersiveScaffold` —— 整页交给它，自带 Scaffold / 抽屉 / 滚动监听，最省事；
//   2. `ImmersiveAppBar`  —— 只想换个标题栏，自己管 Scaffold，把它塞进 appBar 槽。
//
// 性能：模糊**不跟手**。滚动进度先二值化（滚过 50px 即 1，否则 0），
// 模糊由一次 [kImmersiveTransition] 渐变动画完成 —— BackdropFilter 每帧
// readback 在真机上很卡，只让它动个位数的帧次；横带共享一个 backdrop key，
// 一次取样供所有带用。
// ─────────────────────────────────────────────────────────────────────────────

/// 进入滚动态的滚动阈值，对齐网页版 `scrollTop > 50`。
const double kImmersiveScrollThreshold = 50;

/// 材质渐显 / 渐隐时长，对齐网页版 `--navbar-surface-transition: .36s`。
const Duration kImmersiveTransition = Duration(milliseconds: 360);

/// 过渡曲线，与网页版 `cubic-bezier(0.22, 1, 0.36, 1)` 完全一致。
const Cubic kImmersiveCurve = Cubic(0.22, 1, 0.36, 1);

/// 顶部那一条横带的最大模糊 σ，对齐网页版 `blur(20px)`。
const double kImmersiveBlurSigma = 20;

/// 「反正都是糊」的 σ 门槛。
///
/// 实测：σ 过了 8 左右，再往上加对屏幕上的字/线已经没有任何视觉差别了
/// （1px 的笔画和 20px 的字全化成一团）。所以 σ 大于它的那一段用粗步长分带，
/// 只有 σ 小于它的这一段才需要切细 —— 那才是眼睛能看出「逐渐变清」的地方。
const double kImmersiveBlurKnee = 8;

/// 门槛以上（σ > [kImmersiveBlurKnee]）的 σ 步长。看不出差别，带可以很宽。
const double kImmersiveCoarseSigmaStep = 6;

/// 门槛以下（σ < [kImmersiveBlurKnee]）的 σ 步长。看得见变化，带要细。
const double kImmersiveFineSigmaStep = 1;

/// 材质底色的浓度（滚动到位时）：顶部最浓、底部淡出。
///
/// 顶部 0.45 对齐网页版 `card-bg` 45%；底部必须跟着模糊一起淡下去，
/// 否则底下那截「已经不糊了」的区域上还盖着一层底色，看着像玻璃坏了。
const double kImmersiveTintTop = 0.45;
const double kImmersiveTintBottom = 0.10;

/// 标题文字 Key（贴顶 / 滚动两态共用同一条标题）。
const Key kImmersiveTitleKey = Key('immersive-title');

/// 左上角菜单按钮 Key。
const Key kImmersiveMenuKey = Key('immersive-menu');

/// 材质底色 Key（上下渐变的那个 [DecoratedBox]）。
const Key kImmersiveTintKey = Key('immersive-tint');

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

/// 一条渐进模糊横带：纵向范围（相对标题栏顶端）+ 这一段用的模糊 σ。
typedef ImmersiveBlurBand = ({double top, double height, double sigma});

/// 把 [height] 高的标题栏横切成若干条带，**自上而下 σ 递减到 0**。
///
/// 为什么要切带：`ui.ImageFilter.blur` 的 σ 是个常量，没有「纵向渐变」的滤镜，
/// 想让模糊沿着高度变化，只能把标题栏切成窄带、每条各给一个 σ，靠「带够窄」
/// 骗过眼睛。于是内容从标题栏下沿钻出来时是清晰的，越往上越糊 ——
/// 这就是**渐进模糊**。
///
/// σ 与「离标题栏顶端的距离」是线性的，即 `σ(y) = maxSigma * (1 - y / height)`。
/// 切带只是把这条直线做成阶梯，**带切在哪里由 σ 的步长决定**：
///
/// · `σ > ` [kImmersiveBlurKnee]：怎么看都一样糊，用粗步长
///   [kImmersiveCoarseSigmaStep]，两条带就盖掉上半截；
/// · `σ < ` [kImmersiveBlurKnee]：这才是「逐渐变清」的那一段，用细步长
///   [kImmersiveFineSigmaStep] 切密一点。
///
/// 这样切出来大约十条带，只有「等 σ 步长」硬切的一半 —— 每条带一次模糊，
/// 省下来的是实打实的每帧开销。
///
/// 每条带用的 σ 取自己垂直中点处的值（阶梯拟合直线误差最小）。
/// 带的边界按整数像素对齐且严丝合缝（不重叠、不留缝）：重叠会让相邻两条的
/// 模糊叠加、边界处突然变糊，留缝则会在中间露出一线没被模糊的内容。
///
/// 带数与 [height] 无关 —— σ 只跟「占整条的百分之几」有关，所以小屏大屏
/// 切出来一样多。
List<ImmersiveBlurBand> immersiveBlurBands(
  double height, {
  double maxSigma = kImmersiveBlurSigma,
}) {
  if (!height.isFinite || height <= 0 || maxSigma <= 0) return const [];

  // ① 先排 σ 阶梯：粗段 → 门槛 → 细段 → 0
  final steps = <double>[maxSigma];
  if (kImmersiveBlurKnee < maxSigma) {
    for (var s = maxSigma - kImmersiveCoarseSigmaStep;
        s > kImmersiveBlurKnee;
        s -= kImmersiveCoarseSigmaStep) {
      steps.add(s);
    }
    steps.add(kImmersiveBlurKnee);
  }
  if (kImmersiveFineSigmaStep > 0) {
    for (var s = kImmersiveBlurKnee - kImmersiveFineSigmaStep;
        s > 0;
        s -= kImmersiveFineSigmaStep) {
      steps.add(s);
    }
  }
  steps.add(0);

  // ② 再把 σ 阶梯翻译成高度（σ 与 y 是直线关系，两端一反算就得到带的范围）
  double yOf(double sigma) => sigma <= 0
      ? height
      : (height * (1 - sigma / maxSigma)).roundToDouble();

  return [
    for (var i = 0; i < steps.length - 1; i++)
      if (yOf(steps[i + 1]) - yOf(steps[i]) > 0)
        (
          top: yOf(steps[i]),
          height: yOf(steps[i + 1]) - yOf(steps[i]),
          // 取垂直中点处的 σ：阶梯拟合直线这样误差最小
          sigma: maxSigma *
              (1 - (yOf(steps[i]) + yOf(steps[i + 1])) / 2 / height),
        ),
  ];
}

/// 标题栏的材质层：渐进毛玻璃 + 上下渐变底色 + 两条阴影细线。
///
/// 单独抽出来是为了让任何自定义标题栏都能套同一套材质，而不必自己重算
/// 模糊 / 底色 / 细线。**父级高度必须是有限值**：内部铺满父级，父级高度
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
/// ## 渐进模糊（从下到上越来越糊）
///
/// `ui.ImageFilter.blur` 的 σ 是常量、不支持纵向渐变，所以这里把标题栏横切成
/// 一叠窄带、每条各给一个 σ（见 [immersiveBlurBands]）：顶部最糊，向下线性
/// 衰减，最下面一条完全不糊。带够窄时相邻两条的 σ 只差一点点，肉眼看到的
/// 就是一整片自下而上渐强的雾。
///
/// 代价是「一叠带 = 一叠模糊」。为了把代价压回来，所有横带共用同一个
/// [BackdropKey]（[BackdropGroup] + [BackdropFilter.grouped]）：引擎只对
/// backdrop 做**一次**取样再分给每条带，省掉十几次全屏回读。
class ImmersiveGlassLayer extends StatefulWidget {
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
  /// 一眼稳定的像素），关掉后退化为加浓底色 + 两条细线。
  ///
  /// 早先这里有个「Web 上不支持 BackdropFilter」的平台开关，**那是误判**：
  /// 当时把「flexibleSpace 无界高度把模糊层撑到全屏」和「Web 引擎不裁剪」
  /// 两个 bug 混成了一个，一刀切掉 Web 的模糊。实测（见
  /// `test/immersive_app_bar_test.dart` 的平台无关断言 + 逐行量边缘扩散）
  /// CanvasKit 裁剪得好好的，Web 与 Android 的像素曲线几乎逐行重合。
  final bool blur;

  @override
  State<ImmersiveGlassLayer> createState() => _ImmersiveGlassLayerState();
}

class _ImmersiveGlassLayerState extends State<ImmersiveGlassLayer> {
  /// 所有横带共享的 backdrop key。
  ///
  /// **必须跨 rebuild 保持同一个实例**：每帧新建一个 key 就等于每帧换一个
  /// 分组，引擎的「取样一次、共用给所有带」就白做了。
  final BackdropKey _backdropKey = BackdropKey();

  bool get _blurred => widget.blur;

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
      tween: Tween<double>(begin: 0, end: widget.progress.clamp(0.0, 1.0)),
      duration: kImmersiveTransition,
      curve: kImmersiveCurve,
      builder: (context, v, _) {
        // 贴顶态整层不铺（网页版 semifull static 也是全透明），
        // 连 readback 都不发生。
        if (v <= 0.01) return const SizedBox.expand();

        return LayoutBuilder(
          builder: (context, constraints) {
            // 父级高度有限才有「上下的概念」；拿不到就不铺模糊，只留底色细线。
            final height = constraints.maxHeight;
            return BackdropGroup(
              backdropKey: _backdropKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ① 渐进毛玻璃：一叠横带，自上而下 σ 递减
                  if (_blurred) ..._blurBands(height, v),

                  // ② 材质底色：card-bg 45%，向下淡出（网页版 color-mix 45%）
                  _tint(scheme, v),

                  // ③ 顶部内高光细线（网页版 inset 0 1px 0）
                  _line(kImmersiveHighlightKey, highlightColor, v, top: 0),

                  // ④ 底部分发丝线（网页版 0 1px 0）
                  _line(kImmersiveHairlineKey, hairlineColor, v, bottom: 0),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 一叠渐进模糊横带，σ 由 [immersiveBlurBands] 给出（顶部最大、底部为 0）。
  ///
  /// 每条自带 [ClipRect]：BackdropFilter 默认作用于**整个父级裁剪区**，
  /// 不裁的话每条带都会糊满整条标题栏。
  List<Widget> _blurBands(double height, double v) {
    return [
      for (final band in immersiveBlurBands(height))
        // σ 太小的带不值得起一次模糊（最下面那条本来就该是 0）
        if (band.sigma * v > 0.05)
          Positioned(
            left: 0,
            right: 0,
            top: band.top,
            height: band.height,
            child: ClipRect(
              child: BackdropFilter.grouped(
                filter: ui.ImageFilter.blur(
                  sigmaX: band.sigma * v,
                  sigmaY: band.sigma * v,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
    ];
  }

  /// 材质底色：上下渐变，顶部最浓（对齐网页版 `card-bg` 45%）、底部淡出。
  ///
  /// 之所以不铺纯色：底下那截已经没有模糊了，底色要是还在，就会在标题栏
  /// 下沿留下一条「到边就断」的硬边。底色跟着模糊一起淡，内容才算真的
  /// 从标题栏底下长出来。
  Widget _tint(ColorScheme scheme, double v) {
    const aTop = kImmersiveTintTop;
    const aBottom = kImmersiveTintBottom;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          key: kImmersiveTintKey,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surface.withValues(alpha: aTop * v),
                scheme.surface.withValues(alpha: aBottom * v),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 两条阴影细线（顶部内高光 / 底部分发丝线），随进度渐显。
  Widget _line(Key key, Color color, double v, {double? top, double? bottom}) {
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      bottom: bottom,
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
