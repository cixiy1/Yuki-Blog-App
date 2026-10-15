import 'package:flutter/material.dart';

// 导航菜单项实体
typedef NavMenuItem = ({
  IconData icon,
  IconData selectedIcon,
  String label,
  String path,
});

// 用户信息数据模型
class NavUserInfo {
  final String avatarUrl;
  final String userName;
  final String userDesc;

  const NavUserInfo({
    required this.avatarUrl,
    required this.userName,
    required this.userDesc,
  });
}

class AppNavigationDrawer extends StatelessWidget {
  final int selectedIndex;
  final List<NavMenuItem> menuItems;
  final ValueChanged<int> onDestinationSelected;
  // 用户信息，可选传参，不传就不渲染头部
  final NavUserInfo? userInfo;

  const AppNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.menuItems,
    required this.onDestinationSelected,
    this.userInfo,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      children: [
        // ========== 新增：用户信息头部 ==========
        if(userInfo != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: switch (userInfo!.avatarUrl){
                    final url when url.isNotEmpty && url.startsWith("http") => NetworkImage(url),
                    final url when url.isNotEmpty => AssetImage(url) as ImageProvider,
                    _ => const AssetImage("assets/icons/app_icon.png"),
                  },
                  radius: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userInfo!.userName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        userInfo!.userDesc,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // 菜单项，每项后面插入间距，Destination是直接子节点
        ...menuItems.expand((item) sync* {
          yield NavigationDrawerDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          );
          yield const SizedBox(height: 4);
        }),

      ],
    );
  }
}
