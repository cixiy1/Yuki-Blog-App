import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/apk_downloader.dart';
import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/update/apk_installer.dart';
import 'package:yuki_blog_app/features/update/download_progress_dialog.dart';
import 'package:yuki_blog_app/features/update/update_dialog.dart';

const _release = AppRelease(
  tagName: 'v9.9.9',
  notes:
      '**Full Changelog**: https://github.com/cixiy1/Yuki-Blog-App/compare/v9.9.8...v9.9.9',
  apkUrl:
      'https://github.com/cixiy1/Yuki-Blog-App/releases/download/v9.9.9/yuki-blog-v9.9.9.apk',
  releaseUrl: 'https://github.com/cixiy1/Yuki-Blog-App/releases/tag/v9.9.9',
);

Future<void> _open(
  WidgetTester tester, {
  AppRelease release = _release,
  ApkDownloadFn? download,
  ApkInstallFn? install,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUpdateDialog(
              context,
              release: release,
              download: download,
              install: install,
            ),
            child: const Text('打开弹窗'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开弹窗'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('弹窗给出应用内下载与浏览器下载两条路径，并清洗说明里的 Markdown', (tester) async {
    await _open(tester);

    expect(find.text('发现新版本 v9.9.9'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('浏览器下载'), findsOneWidget);
    expect(find.text('稍后再说'), findsOneWidget);
    // GitHub 自动生成的说明带 ** 与链接，展示前要清掉
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('Full Changelog'), findsOneWidget);
  });

  testWidgets('点「立即更新」进入应用内下载弹窗', (tester) async {
    String? requestedUrl;
    String? requestedName;
    await _open(
      tester,
      download: (url, {required fileName, onProgress, cancelToken}) {
        requestedUrl = url;
        requestedName = fileName;
        onProgress?.call(const DownloadProgress(received: 512, total: 1024));
        return Completer<String>().future; // 停在下载中
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(find.text('正在下载 v9.9.9'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('512 B / 1.0 KB'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(requestedUrl, _release.apkUrl);
    expect(requestedName, 'yuki-blog-v9.9.9.apk');
  });

  testWidgets('应用内下载走完后直接交给系统安装器', (tester) async {
    String? installed;
    await _open(
      tester,
      download: (url, {required fileName, onProgress, cancelToken}) async =>
          '/tmp/yuki-blog-v9.9.9.apk',
      install: (path) async {
        installed = path;
        return InstallOutcome.launched;
      },
    );

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(installed, '/tmp/yuki-blog-v9.9.9.apk');
    expect(find.text('已唤起系统安装程序，按提示完成安装'), findsOneWidget);
    // 收尾：等 SnackBar 自动消失，避免留下计时器
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('无 APK 资产时只提供浏览器下载', (tester) async {
    await _open(
      tester,
      release: const AppRelease(
        tagName: 'v9.9.9',
        notes: '',
        apkUrl: '',
        releaseUrl: 'https://github.com/cixiy1/Yuki-Blog-App/releases/tag/v9.9.9',
      ),
    );

    expect(find.text('立即更新'), findsNothing);
    expect(find.text('浏览器下载'), findsOneWidget);
  });
}
