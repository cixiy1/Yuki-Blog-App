import 'package:go_router/go_router.dart';
import 'package:myclass/features/home/home_shell.dart';
import 'package:myclass/app/routes/route_paths.dart';

import 'package:myclass/features/schedule/schedule_page.dart';
import 'package:myclass/features/todo/todo_page.dart';
import 'package:myclass/features/setting/setting_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.home,
  routes: [
    ShellRoute(builder: (context, state, child){
      return HomeShell(child: child);
    },routes: [
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
        path: RoutePaths.setting,
        builder: (context, state) => SettingPage(),
      ),
    ])
  ],
);
