import 'package:flutter/material.dart';

import 'package:yuki_blog_app/widgets/immersive_app_bar.dart';

/// 带「光感沉浸」标题栏的页面骨架 —— 整页交给它就行。
///
/// 它替你做好四件事：
/// 1. 建 Scaffold（含 [drawer] / [floatingActionButton] / [bottomNavigationBar]）；
/// 2. 标题栏换成 [ImmersiveAppBar]（贴顶全透明，滚动后渐显毛玻璃，**只糊标题栏那一条**）；
/// 3. 监听 body 的滚动，换算成标题栏折叠进度（二值，50px 阈值）；
/// 4. body 换实例时自动把标题栏收回贴顶态（避免上一页的滚动状态带过来）。
///
/// ```dart
/// ImmersiveScaffold(
///   title: '待办',
///   drawer: const AppNavigationDrawer(...),
///   body: ListView(...),
/// )
/// ```
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
    this.extendBodyBehindAppBar = false,
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

  /// 内容是否从标题栏底下开始铺（沉浸式的「内容穿透」）。
  /// 默认 false：内容从标题栏下沿开始，标题始终清晰可读。
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
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final t = immersiveProgressOf(notification.metrics);
      if (t != _progress.value) _progress.value = t;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
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
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: widget.body,
      ),
    );
  }
}
