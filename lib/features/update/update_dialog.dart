import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yuki_blog_app/core/update_service.dart';

/// 弹出「发现新版本」对话框。
///
/// - [manual] = true 时用户主动检查，无更新/失败也给出反馈；
///   false 时静默检查，仅在有新版本时弹窗。
/// - 更新动作：跳转浏览器下载 Release 资产里的 APK
///   （GitHub Actions 构建版），失败兜底打开 Release 页面。
Future<void> showUpdateDialog(
  BuildContext context, {
  required AppRelease? release,
  bool manual = false,
}) async {
  if (release == null) {
    if (manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前已是最新版本')),
      );
    }
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
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
                  release.notes.isNotEmpty ? release.notes : '常规更新与问题修复。',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '安装包来自 GitHub Releases，点击「立即更新」在浏览器下载后安装。',
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍后再说'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: const Text('立即更新'),
          onPressed: () => _launchDownload(context, release),
        ),
      ],
    ),
  );
}

Future<void> _launchDownload(BuildContext context, AppRelease release) async {
  Navigator.of(context).pop();
  // 优先 APK 直链（浏览器直接下载安装包），失败打开 Release 页面
  final Uri uri = Uri.tryParse(release.apkUrl) ?? Uri.parse(release.releaseUrl);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(Uri.parse(release.releaseUrl),
        mode: LaunchMode.externalApplication);
  }
}
