import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:yuki_blog_app/app/routes/route_paths.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/home/widgets/nav_view.dart';
import 'package:yuki_blog_app/features/update/update_dialog.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.child, this.services});

  final Widget child;

  /// 校园服务门面；为 null 时用全局实例。
  final CampusServices? services;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final List<NavMenuItem> menuItems = [
    (
      icon: Icons.calendar_view_week_outlined,
      selectedIcon: Icons.calendar_view_week,
      label: "动态课程表",
      shortLabel: "课表",
      path: RoutePaths.schedule,
    ),
    (
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: "待办",
      shortLabel: "待办",
      path: RoutePaths.todo,
    ),
    (
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      label: "校园服务",
      shortLabel: "服务",
      path: RoutePaths.campus,
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: "设置",
      shortLabel: "设置",
      path: RoutePaths.setting,
    ),
  ];

  UpdateService? _updateService;

  /// 当前页标题与选中项：按路由推断（底栏不是唯一入口，URL 直达也对得上）。
  String get _currentPath => GoRouterState.of(context).uri.path;

  /// 最长前缀匹配。
  ///
  /// 用 `startsWith` 单条判断的话，将来出现 `/todo-x` 这类路径会把
  /// `/todo` 抢走；按长度取最长那个才是稳的。
  int get _selectedIndex {
    var best = -1;
    var bestLength = 0;
    for (var i = 0; i < menuItems.length; i++) {
      final path = menuItems[i].path;
      final matched =
          _currentPath == path || _currentPath.startsWith('$path/');
      if (matched && path.length > bestLength) {
        best = i;
        bestLength = path.length;
      }
    }
    return best < 0 ? 0 : best;
  }

  String get _currentTitle =>
      _selectedIndex < menuItems.length ? menuItems[_selectedIndex].label : '';

  CampusServices? get _services =>
      widget.services ?? (CampusServices.isReady ? CampusServices.instance : null);

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
    final services = _services;
    // 标题栏的滚动监听 / 折叠状态 / 路由切换复位都由 ImmersiveScaffold 内部处理
    return ImmersiveScaffold(
      title: _currentTitle,
      bottomNavigationBar: services == null
          ? _nav(0)
          : ValueListenableBuilder<int>(
              valueListenable: services.unread,
              builder: (context, unread, _) => _nav(unread),
            ),
      body: widget.child,
    );
  }

  Widget _nav(int unread) => AppBottomNav(
        selectedIndex: _selectedIndex,
        menuItems: menuItems,
        badgeCount: unread,
        badgePath: RoutePaths.campus,
        onDestinationSelected: (int index) {
          context.go(menuItems[index].path);
        },
      );
}
