import 'package:flutter/material.dart';

import 'package:yuki_blog_app/core/apk_downloader.dart';
import 'package:yuki_blog_app/core/update_service.dart';
import 'package:yuki_blog_app/features/update/apk_installer.dart';
import 'package:yuki_blog_app/features/update/download_progress_dialog.dart';
import 'package:yuki_blog_app/features/update/release_launcher.dart';

/// 弹出「发现新版本」对话框，给出两条更新路径。
///
/// - [manual] = true 时用户主动检查，无更新/失败也给出反馈；
///   false 时静默检查，仅在有新版本时弹窗。
/// - 「立即更新」：应用内下载（带进度条），完成后直接唤起系统安装器；
/// - 「浏览器下载」：跳转浏览器自行下载安装（系统限制应用内安装时的出路）。
/// - [download] / [install] 为实现注入点，默认走真实下载与系统安装器。
Future<void> showUpdateDialog(
  BuildContext context, {
  required AppRelease? release,
  bool manual = false,
  ApkDownloadFn? download,
  ApkInstallFn? install,
}) async {
  if (release == null) {
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前已是最新版本')),
      );
    }
    return;
  }

  final notes = release.displayNotes;
  final hasApk = release.apkUrl.isNotEmpty;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.system_update_alt),
      title: Text('发现新版本 ${release.tagName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '更新内容',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  notes.isNotEmpty ? notes : '常规更新与问题修复。',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasApk
                  ? '安装包来自 GitHub Releases：「立即更新」在应用内下载后直接打开系统安装界面，'
                      '「浏览器下载」则跳到浏览器自行下载安装。'
                  : '安装包来自 GitHub Releases，点击下方按钮在浏览器中下载后安装。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('稍后再说'),
        ),
        TextButton.icon(
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: const Text('浏览器下载'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(dialogContext);
            Navigator.of(dialogContext).pop();
            if (!await launchReleaseDownload(release)) {
              messenger.showSnackBar(
                const SnackBar(content: Text('无法打开浏览器，请手动访问 GitHub Releases')),
              );
            }
          },
        ),
        if (hasApk)
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('立即更新'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showDownloadProgressDialog(
                context,
                release: release,
                download: download ?? downloadToFile,
                install: install ?? launchApkInstaller,
              );
            },
          ),
      ],
    ),
  );
}
