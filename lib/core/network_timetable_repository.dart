import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
  Future<TimetableData> loadTimetable() async =>
      (await loadRaw()).decodeTimetable();

  /// 拉取原始 JSON 文本（供同步数据源写入磁盘缓存）。
  Future<String> loadRaw() async {
    final failures = <String>[];
    for (final url in urls) {
      try {
        final resp =
            await _client.get(url).timeout(timeout);
        if (resp.statusCode != 200) {
          failures.add('${url.host}: HTTP ${resp.statusCode}');
          continue;
        }
        return utf8.decode(resp.bodyBytes);
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

/// 课表 JSON 的磁盘缓存抽象（网络成功后落盘，离线时优先于打包资源）。
abstract class TimetableCache {
  Future<String?> read();
  Future<void> write(String raw);
}

/// 基于 path_provider 临时目录的文件缓存。
///
/// 任何 IO 异常（含 Web 端无实现）一律静默降级为「无缓存」，
/// 不影响课表加载主流程。
class FileTimetableCache implements TimetableCache {
  FileTimetableCache({this.fileName = 'schedule-2615.cache.json'});

  final String fileName;

  Future<File?> _file() async {
    try {
      // 3 秒超时兜底：真机上毫秒级返回；测试环境（未 mock 平台通道）
      // 该 Future 永不完成，不设超时会挂死整个加载流程。
      final dir =
          await getTemporaryDirectory().timeout(const Duration(seconds: 3));
      return File('${dir.path}/$fileName');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> read() async {
    try {
      final file = await _file();
      if (file == null || !file.existsSync()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String raw) async {
    try {
      final file = await _file();
      await file?.writeAsString(raw, flush: true);
    } catch (_) {
      // 写缓存失败不影响主流程。
    }
  }
}

/// 同步数据源（页面默认实现）：网络优先，离线回退「磁盘缓存 → 打包 asset」。
///
/// - 网络可用 → 拉取博客线上最新课表（自动同步，无需发版），并把原始
///   JSON 落盘缓存
/// - 网络失败 → 优先用上次联网成功的缓存；没有缓存（或解析失败）才回退
///   打包进 App 的 `assets/data/schedule-2615.json`。缓存与 asset 都能
///   解析时按 `meta.updated` 取较新的一份，避免 App 升级后旧缓存反超
///   新打包的数据
///
/// 走离线回退时 [usingFallback] 置为 true，UI 据此提示「数据可能不是最新」。
class SyncTimetableRepository implements TimetableRepository {
  SyncTimetableRepository({
    http.Client? client,
    List<Uri>? urls,
    this.assetPath = 'assets/data/schedule-2615.json',
    TimetableCache? cache,
  })  : _remote = RemoteTimetableRepository(client: client, urls: urls),
        _cache = cache ?? FileTimetableCache();

  final RemoteTimetableRepository _remote;
  final String assetPath;
  final TimetableCache _cache;

  /// 当前展示的数据是否来自离线回退（true = 网络拉取失败，数据可能过期）。
  final ValueNotifier<bool> usingFallback = ValueNotifier(false);

  @override
  Future<TimetableData> loadTimetable() async {
    String raw;
    try {
      raw = await _remote.loadRaw();
      usingFallback.value = false;
    } on TimetableNetworkException {
      // 离线 / 代理异常：优先磁盘缓存（上次联网拉到的新数据），
      // 与打包 asset 按 meta.updated 取新者，都没有才不可能——asset 必在。
      usingFallback.value = true;
      return _loadOffline();
    }
    // 网络数据落盘，供离线时使用；写失败不影响本次返回。
    unawaited(_cache.write(raw));
    return raw.decodeTimetable();
  }

  Future<TimetableData> _loadOffline() async {
    final cachedRaw = await _cache.read();
    TimetableData? cached;
    if (cachedRaw != null) {
      try {
        cached = cachedRaw.decodeTimetable();
      } catch (_) {
        cached = null; // 缓存损坏按无缓存处理。
      }
    }

    final assetRaw = await rootBundle.loadString(assetPath);
    final asset = assetRaw.decodeTimetable();

    if (cached == null) return asset;
    // 两者都可用：meta.updated 较新者胜（ISO 日期字符串可直接比较，
    // 但仍按日期解析，格式异常时保守返回缓存——它通常是最近拉到的）。
    final cachedTime = DateTime.tryParse(cached.meta.updated);
    final assetTime = DateTime.tryParse(asset.meta.updated);
    if (cachedTime != null && assetTime != null) {
      return cachedTime.isAfter(assetTime) ? cached : asset;
    }
    return cached;
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
