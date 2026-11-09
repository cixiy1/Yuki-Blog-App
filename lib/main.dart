import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/app.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 校园服务依赖本地库与登录态；启动失败也要让课表能用，
  // 所以这里兜住异常，不让整个 App 打不开。
  try {
    await CampusServices.bootstrap();
  } catch (e) {
    debugPrint('校园服务初始化失败：$e');
  }

  runApp(const MyApp());
}
