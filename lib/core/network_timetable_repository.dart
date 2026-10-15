import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:yuki_blog_app/core/asset_timetable_repository.dart';
import 'package:yuki_blog_app/core/timetable_repository.dart';
import 'package:yuki_blog_app/models/timetable.dart';

/// 网络数据源：自动下载同步博客线上仓库的课表 JSON。
///
/// 按 [urls] 顺序依次尝试（超时 [timeout] 即换下一个），
/// 任一成功即解析返回；全部失败抛 [TimetableNetworkException]。
///
/// 默认候选（同源同格式，均为 `public/assets/data/schedule-2615.json` 的发布产物）：
/// 1. yiyu14.top —— Cloudflare Pages 线上站点（国内访问最快，首选）
/// 2. raw.githubusercontent.com —— GitHub 仓库源（master 分支）
/// 3. cdn.jsdelivr.net —— jsDelivr CDN 镜像
class RemoteTimetableRepository implements TimetableRepository {
  RemoteTimetableRepository({
    http.Client? client,
    List<Uri>? urls,
    this.timeout = const Duration(seconds: 8),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        urls = urls ?? defaultUrls;

  /// 线上课表 JSON 的候选地址，按优先级排列。
  static final List<Uri> defaultUrls = [
    Uri.parse('https://yiyu14.top/assets/data/schedule-2615.json'),
    Uri.parse(
        'https://raw.githubusercontent.com/cixiy1/Yuki-blog/master/'
        'public/assets/data/schedule-2615.json'),
    Uri.parse(
        'https://cdn.jsdelivr.net/gh/cixiy1/Yuki-blog@master/'
        'public/assets/data/schedule-2615.json'),
  ];

  final http.Client _client;
  final bool _ownsClient;
  final List<Uri> urls;
  final Duration timeout;

  /// 释放自建的底层连接（外部注入的 client 由注入方管理）。
  void dispose() {
    if (_ownsClient) _client.close();
  }

  @override
  Future<TimetableData> loadTimetable() async {
    final failures = <String>[];
    for (final url in urls) {
      try {
        final resp =
            await _client.get(url).timeout(timeout);
        if (resp.statusCode != 200) {
          failures.add('${url.host}: HTTP ${resp.statusCode}');
          continue;
        }
        return utf8.decode(resp.bodyBytes).decodeTimetable();
      } catch (e) {
        failures.add('${url.host}: $e');
      }
    }
    throw TimetableNetworkException(
      '线上课表全部拉取失败',
      failures,
    );
  }
}

/// 同步数据源（页面默认实现）：网络优先，离线自动回退本地 asset。
///
/// - 网络可用 → 拉取博客线上最新课表（自动同步，无需发版）
/// - 网络失败 → 回退打包进 App 的 `assets/data/schedule-2615.json`
///
/// 回退时 [usingFallback] 置为 true，UI 据此提示「数据可能不是最新」。
class SyncTimetableRepository implements TimetableRepository {
  SyncTimetableRepository({
    http.Client? client,
    List<Uri>? urls,
    this.assetPath = 'assets/data/schedule-2615.json',
  }) : _remote = RemoteTimetableRepository(client: client, urls: urls);

  final RemoteTimetableRepository _remote;
  final String assetPath;

  /// 当前展示的数据是否来自离线回退（true = 网络拉取失败，数据可能过期）。
  final ValueNotifier<bool> usingFallback = ValueNotifier(false);

  @override
  Future<TimetableData> loadTimetable() async {
    try {
      final data = await _remote.loadTimetable();
      usingFallback.value = false;
      return data;
    } on TimetableNetworkException {
      // 离线 / 代理异常：回退本地资源，保证课表始终可用。
      usingFallback.value = true;
      final raw = await rootBundle.loadString(assetPath);
      return raw.decodeTimetable();
    }
  }

  /// 释放底层网络连接与状态通知器（仅在页面持有自建数据源时调用）。
  void dispose() {
    _remote.dispose();
    usingFallback.dispose();
  }
}

/// 网络拉取失败时抛出，[failures] 记录每个候选地址的失败原因。
class TimetableNetworkException implements Exception {
  const TimetableNetworkException(this.message, this.failures);
  final String message;
  final List<String> failures;

  @override
  String toString() =>
      'TimetableNetworkException: $message\n${failures.join('\n')}';
}
