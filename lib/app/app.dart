import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/routes/app_router.dart';
import 'package:yuki_blog_app/app/theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Yuki-Blog App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system, // 跟随系统深浅色
      routerConfig: appRouter,
    );
  }
}
