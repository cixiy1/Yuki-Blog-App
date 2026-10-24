import 'package:flutter/material.dart';

import 'package:yuki_blog_app/widgets/immersive_app_bar.dart';

/// 带「光感沉浸」标题栏的页面骨架 —— 整页交给它就行。
///
/// 它替你做好五件事：
/// 1. 建 Scaffold（含 [drawer] / [floatingActionButton] / [bottomNavigationBar]）；
/// 2. 标题栏换成 [ImmersiveAppBar]（贴顶全透明，滚动后渐显毛玻璃，**只糊标题栏那一条**）；
/// 3. **内容从标题栏底下穿过**（默认 `extendBodyBehindAppBar: true`）——
///    这是玻璃效果能看得见的前提，否则模糊层糊到的只是一片纯背景色；
/// 4. 监听 body 的**页面级**滚动，换算成标题栏折叠进度（二值，50px 阈值）；
///    页面内嵌的滚动组件（更新历列表、课程表横向滚动）不参与换算；
/// 5. body 换实例时自动把标题栏收回贴顶态（避免上一页的滚动状态带过来）。
///
/// ```dart
/// ImmersiveScaffold(
///   title: '待办',
///   drawer: const AppNavigationDrawer(...),
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
class ImmersiveScaffold extends StatefulWidget {
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
  State<ImmersiveScaffold> createState() => _ImmersiveScaffoldState();
}

class _ImmersiveScaffoldState extends State<ImmersiveScaffold> {
  /// 用 GlobalKey 拿 ScaffoldState 开抽屉：比 `Scaffold.of(context)` 稳，
  /// 不依赖「context 在 Scaffold 之下」这个前提。
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 标题栏折叠状态（0 = 贴顶全透明，1 = 滚过阈值成毛玻璃）。
  /// 用 ValueNotifier 而非 setState：滚动时只重建标题栏材质层，不动整棵树。
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ImmersiveScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // body 换实例（如 Shell 切换子路由）时把标题栏收回贴顶态，
    // 避免上一页的滚动状态残留到新页。
    if (!identical(oldWidget.body, widget.body)) _progress.value = 0;
  }

  /// 页面滚动 → 标题栏折叠进度（二值，对齐网页版 scrollTop > 50）。
  /// 返回 false 让通知继续冒泡。
  ///
  /// **只认页面自己那个滚动视图**（`depth == 0`）。页面里嵌的可滚动组件——
  /// 数据更新历内层的 `SingleChildScrollView`、课程表的横向滚动——它们的
  /// `metrics.pixels` 是自己内部的位移，跟页面滚没滚毫无关系。之前没做这层
  /// 过滤，拖一下更新历列表（内层滚过 50px）标题栏就糊上了，往回拖又糊然
  /// 消失，看着像顶部模糊被列表带着抖。
  ///
  /// `depth` 是「这条通知往上穿过了几层 viewport」，页面级滚动恒为 0，
  /// 内层滚动的通知穿过外层 ListView 的 viewport 后至少是 1。
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollUpdateNotification) {
      final t = immersiveProgressOf(notification.metrics);
      if (t != _progress.value) _progress.value = t;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 标题栏实际占掉的高度：状态栏 + 工具栏行
    final barHeight = media.padding.top + kToolbarHeight;
    // 内容穿透时把这份高度补回 body 的 MediaQuery —— Scaffold 挂 appBar 时
    // 会把 body 的 padding.top 清成 0，不补回来的话滚动视图与 SafeArea 都会
    // 一头顶到屏幕最上面。补上之后：ListView（padding 为 null）自动留白，
    // 页面里写死 padding 的地方按 paddingOf().top 取用即可。
    final bodyMedia = widget.extendBodyBehindAppBar
        ? media.copyWith(padding: media.padding.copyWith(top: barHeight))
        : media;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      drawer: widget.drawer,
      endDrawer: widget.endDrawer,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.bottomNavigationBar,
      appBar: ImmersiveAppBar(
        title: widget.title,
        progress: _progress,
        leading: widget.leading,
        actions: widget.actions,
        onMenu: widget.drawer == null
            ? null
            : () => _scaffoldKey.currentState?.openDrawer(),
      ),
      body: MediaQuery(
        data: bodyMedia,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: widget.body,
        ),
      ),
    );
  }
}
