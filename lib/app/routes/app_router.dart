import 'package:go_router/go_router.dart';
import 'package:yuki_blog_app/features/home/home_shell.dart';
import 'package:yuki_blog_app/app/routes/route_paths.dart';

import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/features/campus/auth/login_page.dart';
import 'package:yuki_blog_app/features/campus/auth/register_page.dart';
import 'package:yuki_blog_app/features/campus/portal/campus_portal_page.dart';
import 'package:yuki_blog_app/features/schedule/schedule_page.dart';
import 'package:yuki_blog_app/features/todo/todo_page.dart';
import 'package:yuki_blog_app/features/setting/setting_page.dart';

/// 组装路由表。
///
/// [services] 为 null 时跳过登录守卫——测试里可以只挂一个页面，
/// 不必先把整套服务跑起来。
GoRouter buildAppRouter({CampusServices? services}) {
  return GoRouter(
    initialLocation: RoutePaths.home,
    refreshListenable: services?.session,
    redirect: (context, state) => _guard(services, state),
    routes: [
      // 登录 / 注册不套 Shell，整屏显示。
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => LoginPage(services: services),
      ),
      GoRoute(
        path: RoutePaths.register,
        builder: (context, state) => RegisterPage(services: services),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(services: services, child: child),
        routes: [
          GoRoute(
            path: RoutePaths.home,
            builder: (context, state) => SchedulePage(),
          ),
          GoRoute(
            path: RoutePaths.schedule,
            builder: (context, state) => SchedulePage(),
          ),
          GoRoute(
            path: RoutePaths.todo,
            builder: (context, state) => TodoPage(),
          ),
          GoRoute(
            path: RoutePaths.campus,
            builder: (context, state) => CampusPortalPage(services: services),
          ),
          GoRoute(
            path: RoutePaths.setting,
            builder: (context, state) => SettingPage(services: services),
          ),
        ],
      ),
    ],
  );
}

/// 只拦「校园服务」；课表 / 待办 / 设置保持免登录。
String? _guard(CampusServices? services, GoRouterState state) {
  final path = state.uri.path;
  final loggedIn = services?.session.isLoggedIn ?? false;

  // 深链未登录 → 记下目标，登录后原路返回。
  final needsAuth = RoutePaths.guardedPrefixes.any(
    (prefix) => path == prefix || path.startsWith('$prefix/'),
  );
  if (!loggedIn && needsAuth) {
    return '${RoutePaths.login}?from=${Uri.encodeComponent(path)}';
  }

  // 已登录还停在登录页 → 送去原本要去的页面。
  if (loggedIn && RoutePaths.isAuthPage(path)) {
    final from = state.uri.queryParameters['from'];
    if (from != null &&
        from.startsWith('/') &&
        !RoutePaths.isAuthPage(from)) {
      return from;
    }
    return RoutePaths.campus;
  }

  return null;
}

/// 全局单例。
///
/// Dart 的顶层 final 是懒初始化的，第一次读到它时 `main()` 里的
/// `CampusServices.bootstrap()` 已经跑完，所以这里能拿到服务实例。
final GoRouter appRouter = buildAppRouter(
  services: CampusServices.isReady ? CampusServices.instance : null,
);
