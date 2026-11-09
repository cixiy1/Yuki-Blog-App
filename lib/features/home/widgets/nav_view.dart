import 'package:flutter/material.dart';

// 导航菜单项实体
typedef NavMenuItem = ({
  IconData icon,
  IconData selectedIcon,
  String label,
  String path,
});

/// 底部导航栏（M3 NavigationBar）。
///
/// 选中项由 HomeShell 按当前路由推导后传入，路由直达（URL 冷启动）也高亮正确。
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final List<NavMenuItem> menuItems;
  final ValueChanged<int> onDestinationSelected;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.menuItems,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (final item in menuItems)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: item.label,
          ),
      ],
    );
  }
}
