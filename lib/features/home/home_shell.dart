import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:yuki_blog_app/features/home/widgets/nav_view.dart';

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
    userDesc: "yuki@example.com",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
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
