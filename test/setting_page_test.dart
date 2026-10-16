import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yuki_blog_app/features/setting/setting_page.dart';

void main() {
  Widget wrap() => MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: const Scaffold(body: SettingPage()),
      );

  testWidgets('显示当前安装版本（读系统里的实际值）', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Yuki Blog',
      packageName: 'com.yiyu14.yuki_blog_app',
      version: '1.4.4',
      buildNumber: '14',
      buildSignature: '',
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('1.4.4+14'), findsOneWidget);
  });

  testWidgets('没有 build 号时只显示版本号', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Yuki Blog',
      packageName: 'com.yiyu14.yuki_blog_app',
      version: '1.4.4',
      buildNumber: '',
      buildSignature: '',
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('1.4.4'), findsOneWidget);
  });

  testWidgets('点一下复制版本号，并给出反馈', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Yuki Blog',
      packageName: 'com.yiyu14.yuki_blog_app',
      version: '1.4.4',
      buildNumber: '14',
      buildSignature: '',
    );

    // 拦下剪贴板通道，断言真的写进去了
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('当前版本'));
    await tester.pumpAndSettle();

    final copied = calls
        .where((c) => c.method == 'Clipboard.setData')
        .map((c) => (c.arguments as Map)['text'])
        .toList();
    expect(copied, ['1.4.4+14']);
    expect(find.textContaining('已复制版本号'), findsOneWidget);
  });

  testWidgets('检查更新入口仍在', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Yuki Blog',
      packageName: 'com.yiyu14.yuki_blog_app',
      version: '1.4.4',
      buildNumber: '14',
      buildSignature: '',
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('检查更新'), findsOneWidget);
  });
}
