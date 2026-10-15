import 'package:url_launcher/url_launcher.dart';

import 'package:yuki_blog_app/core/update_service.dart';

/// 在浏览器里下载 Release 资产里的 APK；直链不可用时退回 Release 页面。
/// 返回是否成功唤起浏览器。
Future<bool> launchReleaseDownload(AppRelease release) async {
  final candidates = <String>[
    if (release.apkUrl.isNotEmpty) release.apkUrl,
    if (release.releaseUrl.isNotEmpty) release.releaseUrl,
  ];
  for (final candidate in candidates) {
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme) continue;
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  }
  return false;
}

/// 打开 Release 说明页面。
Future<bool> openReleasePage(AppRelease release) async {
  final uri = Uri.tryParse(release.releaseUrl);
  if (uri == null || !uri.hasScheme) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
