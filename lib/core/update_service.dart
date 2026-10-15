import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub 上的最新 Release 信息。
class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.notes,
    required this.apkUrl,
    required this.releaseUrl,
  });

  /// 形如 `v1.1.0`。
  final String tagName;
  final String notes;

  /// Release 资产里的 APK 下载直链（GitHub Actions 构建产物）。
  final String apkUrl;

  /// Release 页面（APK 直链不可用时的兜底跳转）。
  final String releaseUrl;
}

/// 应用内更新检查：比对 GitHub 最新 Release 与当前安装版本。
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const _repo = 'cixiy1/Yuki-Blog-App';
  final http.Client _client;

  /// 拉取最新 Release；无更新/网络失败返回 null。
  Future<AppRelease?> checkForUpdate() async {
    try {
      final resp = await _client.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final tag = json['tag_name'] as String? ?? '';
      if (tag.isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      if (!isNewer(tag, info.version)) return null;

      final assets = (json['assets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final apk = assets.where((a) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        return name.endsWith('.apk');
      }).map((a) => a['browser_download_url'] as String).toList();

      return AppRelease(
        tagName: tag,
        notes: (json['body'] as String? ?? '').trim(),
        apkUrl: apk.isNotEmpty ? apk.first : '',
        releaseUrl: json['html_url'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// 语义化版本比较：remote 大于 current 返回 true。
  /// 兼容 `v` 前缀与 `+build` 后缀，解析失败的段按 0 处理。
  static bool isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (r[i] != c[i]) return r[i] > c[i];
    }
    return false;
  }

  static List<int> _parse(String version) {
    final core = version
        .trim()
        .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
        .split('+')
        .first;
    final parts = core.split('.');
    return List.generate(3, (i) => int.tryParse(parts[i]) ?? 0);
  }

  void dispose() => _client.close();
}
