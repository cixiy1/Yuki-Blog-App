import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/apk_downloader.dart';
import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/update/apk_installer.dart';
import 'package:yuki_blog_app/features/update/download_progress_dialog.dart';

const _release = AppRelease(
  tagName: 'v9.9.9',
  notes: '',
  apkUrl:
      'https://github.com/cixiy1/Yuki-Blog-App/releases/download/v9.9.9/yuki-blog-v9.9.9.apk',
  releaseUrl: 'https://github.com/cixiy1/Yuki-Blog-App/releases/tag/v9.9.9',
);

Future<void> _openDialog(
  WidgetTester tester, {
  required ApkDownloadFn download,
  ApkInstallFn? install,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDownloadProgressDialog(
              context,
              release: _release,
              download: download,
              install: install ?? (_) async => InstallOutcome.launched,
            ),
            child: const Text('开始下载'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('开始下载'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // 不确定进度条会一直动画，pumpAndSettle 永远等不到静止
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('下载中显示进度条、百分比与「取消」', (tester) async {
    await _openDialog(
      tester,
      download: (url, {required fileName, onProgress, cancelToken}) {
        onProgress?.call(const DownloadProgress(received: 512, total: 1024));
        return Completer<String>().future;
      },
    );

    expect(find.text('正在下载 v9.9.9'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.textContaining('512 B / 1.0 KB'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      0.5,
    );
  });

  testWidgets('总长未知时用不确定进度条', (tester) async {
    await _openDialog(
      tester,
      settle: false,
      download: (url, {required fileName, onProgress, cancelToken}) {
        onProgress?.call(const DownloadProgress(received: 2048, total: 0));
        return Completer<String>().future;
      },
    );

    expect(find.textContaining('已下载 2.0 KB'), findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value,
      isNull,
    );
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('下载完成 + 安装器打开成功：弹窗关闭并提示', (tester) async {
    String? installed;
    await _openDialog(
      tester,
      download: (url, {required fileName, onProgress, cancelToken}) async =>
          '/tmp/yuki-blog-v9.9.9.apk',
      install: (path) async {
        installed = path;
        return InstallOutcome.launched;
      },
    );

    expect(installed, '/tmp/yuki-blog-v9.9.9.apk');
    expect(find.text('正在下载 v9.9.9'), findsNothing);
    expect(find.text('已唤起系统安装程序，按提示完成安装'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('系统未授权安装：只给「浏览器下载」出路，不给无意义的重试', (tester) async {
    await _openDialog(
      tester,
      download: (url, {required fileName, onProgress, cancelToken}) async => '/tmp/x.apk',
      install: (_) async => InstallOutcome.permissionDenied,
    );

    expect(find.text('下载失败'), findsOneWidget);
    expect(find.textContaining('系统未允许本应用安装应用'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(find.text('浏览器下载'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('无法唤起安装器时提示失败并可重试', (tester) async {
    await _openDialog(
      tester,
      download: (url, {required fileName, onProgress, cancelToken}) async => '/tmp/x.apk',
      install: (_) async => InstallOutcome.failed,
    );

    expect(find.textContaining('无法唤起系统安装程序'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('浏览器下载'), findsOneWidget);
  });

  testWidgets('下载报错：显示原因、可重试', (tester) async {
    var attempts = 0;
    await _openDialog(
      tester,
      download: (url, {required fileName, onProgress, cancelToken}) async {
        attempts++;
        if (attempts == 1) throw DownloadException('连接超时，请检查网络后重试');
        return '/tmp/yuki-blog-v9.9.9.apk';
      },
    );

    expect(find.text('下载失败'), findsOneWidget);
    expect(find.text('连接超时，请检查网络后重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('已唤起系统安装程序，按提示完成安装'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('下载中点「取消」会中止并关闭弹窗', (tester) async {
    await _openDialog(
      tester,
      download: (url, {required fileName, onProgress, cancelToken}) async {
        onProgress?.call(const DownloadProgress(received: 1, total: 100));
        while (!(cancelToken?.isCancelled ?? false)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        throw DownloadCancelledException();
      },
    );
    expect(find.text('取消'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(find.text('正在下载 v9.9.9'), findsNothing);
    expect(find.text('下载失败'), findsNothing);
  });
}
