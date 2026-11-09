import 'package:flutter/material.dart';

import 'package:yuki_blog_app/widgets/immersive_app_bar.dart';

/// 带「光感沉浸」标题栏的页面骨架 —— 整页交给它就行。
///
/// 它替你做好四件事：
/// 1. 建 Scaffold（含 [drawer] / [floatingActionButton] / [bottomNavigationBar]）；
/// 2. 标题栏换成 [ImmersiveAppBar]（**全程毛玻璃**，只糊标题栏那一条）；
/// 3. **内容从标题栏底下穿过**（默认 `extendBodyBehindAppBar: true`）——
///    这是玻璃效果能看得见的前提，否则模糊层糊到的只是一片纯背景色；
/// 4. body 换实例时玻璃照常显示（材质是常驻的，不随页面滚动状态变化）。
///
/// 曾经监听页面级滚动、按 50px 阈值二值化折叠进度（贴顶全透明、滚过渐显）；
/// 2026-11-09 改为全程模糊后，这套进度机制整块删掉了。
///
/// ```dart
/// ImmersiveScaffold(
///   title: '待办',
///   body: ListView(...),
/// )
/// ```
///
/// ## 内容穿透时的留白（踩坑点）
///
/// `Scaffold` 只要挂了 `appBar`，就会把 body 的 `MediaQuery.padding.top` **清成 0**，
/// 所以「内容避开标题栏」这件事得自己安排。本组件在穿透模式下会把
/// **「状态栏 + 工具栏」的高度重新补进 body 的 MediaQuery padding**，于是：
///
/// - `ListView` / `GridView` **在 `padding` 为 null 时**会自动留出这段
///   （框架行为：padding 显式给了就不会再套 MediaQuery）；
/// - 页面里写死 `padding` 的滚动视图，自己用
///   `MediaQuery.paddingOf(context).top` 补上同样一段即可（参考课表页）；
/// - `SafeArea` 也会按这个 padding 避让 —— 但**要让内容能钻进标题栏下面，
///   页面根部的 `SafeArea` 必须 `top: false`**，否则滚动视口整块被压到条下面，
///   内容永远穿不过去。
///
/// 只想换标题栏、Scaffold 要自己管的，直接用 [ImmersiveAppBar]。
class ImmersiveScaffold extends StatelessWidget {
  const ImmersiveScaffold({
    super.key,
    required this.title,
    required this.body,
    this.drawer,
    this.leading,
    this.actions,
    this.endDrawer,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.extendBodyBehindAppBar = true,
    this.resizeToAvoidBottomInset,
  });

  /// 页名。
  final String title;

  /// 页面内容。
  final Widget body;

  /// 左侧抽屉；给了它标题栏左侧就是菜单按钮。
  final Widget? drawer;

  /// 右侧抽屉。
  final Widget? endDrawer;

  /// 自定义左侧组件（覆盖菜单 / 返回键）。
  final Widget? leading;

  /// 标题栏右侧动作。
  final List<Widget>? actions;

  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  /// 内容是否从标题栏底下开始铺（**默认 true：真沉浸**）。
  ///
  /// true 时 body 从屏幕顶端（y = 0）开始，滚动内容会从标题栏下方穿过，
  /// 毛玻璃才有东西可糊；同时把「状态栏 + 工具栏」的高度补进 body 的
  /// `MediaQuery` padding，让滚动视图与 [SafeArea] 自动避让（详见类注释）。
  ///
  /// 设成 false 则退回普通布局：body 从标题栏下沿开始，内容永远不会钻到
  /// 标题栏下面，毛玻璃只糊到一片背景色。
  final bool extendBodyBehindAppBar;

  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 标题栏实际占掉的高度：状态栏 + 工具栏行
    final barHeight = media.padding.top + kToolbarHeight;
    // 内容穿透时把这份高度补回 body 的 MediaQuery —— Scaffold 挂 appBar 时
    // 会把 body 的 padding.top 清成 0，不补回来的话滚动视图与 SafeArea 都会
    // 一头顶到屏幕最上面。补上之后：ListView（padding 为 null）自动留白，
    // 页面里写死 padding 的地方按 paddingOf().top 取用即可。
    final bodyMedia = extendBodyBehindAppBar
        ? media.copyWith(padding: media.padding.copyWith(top: barHeight))
        : media;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      drawer: drawer,
      endDrawer: endDrawer,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      appBar: ImmersiveAppBar(
        title: title,
        leading: leading,
        actions: actions,
        // 菜单键不用显式传：ImmersiveAppBar 会经 Scaffold.maybeOf 发现
        // 抽屉并自动放一个开抽屉的菜单按钮（见其 leading 推导顺序）。
      ),
      body: MediaQuery(
        data: bodyMedia,
        child: body,
      ),
    );
  }
}
