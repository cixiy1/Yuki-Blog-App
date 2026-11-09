import 'package:flutter/material.dart';

// 导航菜单项实体。[shortLabel] 用于窄屏，避免「动态课程表」五个字被挤到换行。
typedef NavMenuItem = ({
  IconData icon,
  IconData selectedIcon,
  String label,
  String shortLabel,
  String path,
});

/// 底部导航栏（M3 NavigationBar）。
///
/// 选中项由 HomeShell 按当前路由推导后传入，路由直达（URL 冷启动）也高亮正确。
/// [badgeCount] > 0 时在 [badgePath] 对应的那项上挂一个未读角标。
class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final List<NavMenuItem> menuItems;
  final ValueChanged<int> onDestinationSelected;
  final int badgeCount;
  final String? badgePath;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.menuItems,
    required this.onDestinationSelected,
    this.badgeCount = 0,
    this.badgePath,
  });

  Widget _withBadge(NavMenuItem item, Widget icon) {
    if (badgeCount <= 0 || badgePath == null || item.path != badgePath) {
      return icon;
    }
    return Badge.count(count: badgeCount, child: icon);
  }

  @override
  Widget build(BuildContext context) {
    // 320dp 这类窄屏放不下五个字的标签，换成短名并把字号压到 11。
    final narrow = MediaQuery.sizeOf(context).width < 400;
    final base = Theme.of(context).navigationBarTheme;

    final bar = NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        for (final item in menuItems)
          NavigationDestination(
            icon: _withBadge(item, Icon(item.icon)),
            selectedIcon: _withBadge(item, Icon(item.selectedIcon)),
            label: narrow ? item.shortLabel : item.label,
          ),
      ],
    );

    if (!narrow) return bar;

    return NavigationBarTheme(
      data: base.copyWith(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final scheme = Theme.of(context).colorScheme;
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      child: bar,
    );
  }
}
