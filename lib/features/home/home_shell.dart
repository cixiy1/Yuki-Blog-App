import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/home/widgets/nav_view.dart';
import 'package:yuki_blog_app/features/update/update_dialog.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

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

  /// 当前页标题：按路由推断（抽屉是唯一入口，URL 直达也对得上）。
  String get _currentTitle {
    final path = GoRouterState.of(context).uri.path;
    for (final item in menuItems) {
      if (path.startsWith(item.path)) return item.label;
    }
    return 'Yuki Blog';
  }

  @override
  void initState() {
    super.initState();
    _checkUpdateSilently();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 标题栏的滚动监听 / 折叠状态 / 路由切换复位都由 ImmersiveScaffold 内部处理
    return ImmersiveScaffold(
      title: _currentTitle,
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
      body: widget.child,
    );
  }
}
