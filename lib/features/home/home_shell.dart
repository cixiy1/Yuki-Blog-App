import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/home/widgets/glass_app_bar.dart';
import 'package:yuki_blog_app/features/home/widgets/nav_view.dart';
import 'package:yuki_blog_app/features/update/update_dialog.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final List<({IconData icon, IconData selectedIcon, String label, String path})> menuItems = [
    (
      icon: Icons.calendar_view_week_outlined,
      selectedIcon: Icons.calendar_view_week,
      label: "动态课程表",
      path: "/schedule",
    ),
    (
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: "待办",
      path: "/todo",
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: "设置",
      path: "/setting",
    ),
  ];

  int _selectedNavIndex = 0;

  final NavUserInfo _userInfo = const NavUserInfo(
    avatarUrl: "assets/icons/app_icon.png",
    userName: "雪穗",
    userDesc: "天涯何处无芳草",
  );

  UpdateService? _updateService;

  /// 标题栏折叠状态（0 = 贴顶全透明，1 = 滚过阈值成毛玻璃），
  /// 喂给网页版同款的「光感沉浸」标题栏。用 ValueNotifier 而非
  /// setState：切换时只重建标题栏玻璃层，不动整棵树。
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _checkUpdateSilently();
  }

  /// 当前页标题：按路由推断（抽屉是唯一入口，URL 直达也对得上）。
  String get _currentTitle {
    final path = GoRouterState.of(context).uri.path;
    for (final item in menuItems) {
      if (path.startsWith(item.path)) return item.label;
    }
    return 'Yuki Blog';
  }

  /// 启动时静默检查更新，仅在有新版本时弹窗。
  Future<void> _checkUpdateSilently() async {
    final service = _updateService ??= UpdateService();
    final release = await service.checkForUpdate();
    if (!mounted || release == null) return;
    // 等首帧渲染完成再弹，避免与路由转场抢焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showUpdateDialog(context, release: release);
    });
  }

  @override
  void dispose() {
    _updateService?.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 路由切换（子页面换实例）时把标题栏收回贴顶态，
    // 避免上一页的滚动状态残留到新页。
    if (oldWidget.child != widget.child) _scrollProgress.value = 0;
  }

  /// 页面滚动 → 标题栏折叠状态（二值，对齐网页版 scrollTop > 50）。
  /// 返回 false 让通知继续冒泡。
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final t = glassProgressOf(notification.metrics);
      if (t != _scrollProgress.value) _scrollProgress.value = t;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: glassAppBar(
        title: _currentTitle,
        progress: _scrollProgress,
        brightness: Theme.of(context).brightness,
        onMenu: () => Scaffold.of(context).openDrawer(),
      ),
      drawer: AppNavigationDrawer(
        selectedIndex: _selectedNavIndex,
        menuItems: menuItems,
        userInfo: _userInfo,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedNavIndex = index;
          });
          Navigator.pop(context);
          final item = menuItems[index];
          context.go(item.path);
        },
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: widget.child,
      ),
    );
  }
}
