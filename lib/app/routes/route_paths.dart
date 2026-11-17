class RoutePaths {
  /// 启动页。App 冷启动的初始落点，展示品牌与标语后跳 [home]。
  static const String splash = '/splash';

  static const String home = '/home';
  static const String schedule = '/schedule';
  static const String todo = '/todo';
  static const String setting = '/setting';

  /// 校园服务门户（底栏第 4 项之外的第 3 项）。
  static const String campus = '/campus';

  /// 登录 / 注册。挂在 ShellRoute 之外，没有底栏。
  static const String login = '/login';
  static const String register = '/register';

  /// 需要登录才允许进入的一级路径前缀。
  static const List<String> guardedPrefixes = [campus];

  /// 免登录即可访问的页面（防止守卫把它们自己重定向走）。
  static bool isAuthPage(String path) => path == login || path == register;
}
