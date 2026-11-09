import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuki_blog_app/core/network_timetable_repository.dart';

/// 真实线上数据（与 assets/data/schedule-2615.json 同源），用于断言解析。
late final String _validJson;

http.Response _ok(String body) => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  // rootBundle 回退路径需要 ServicesBinding。
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _validJson = await rootBundle.loadString('assets/data/schedule-2615.json');
  });
  group('RemoteTimetableRepository 自动下载线上课表', () {
    test('按候选顺序重试：首个地址 500，第二个成功并正确解析', () async {
      final hits = <String>[];
      final repo = RemoteTimetableRepository(
        client: MockClient((req) async {
          hits.add(req.url.host);
          if (req.url.host == 'yiyu14.top') {
            return http.Response('server error', 500);
          }
          return _ok(_validJson);
        }),
      );

      final data = await repo.loadTimetable();
      expect(hits, ['yiyu14.top', 'raw.githubusercontent.com']);
      expect(data.meta.className, contains('2615'));
      expect(data.courses.first.id, 'c01');
      repo.dispose();
    });

    test('全部候选失败时抛 TimetableNetworkException，并携带失败原因', () async {
      final repo = RemoteTimetableRepository(
        client: MockClient((req) async => http.Response('nope', 404)),
      );

      await expectLater(
        repo.loadTimetable(),
        throwsA(isA<TimetableNetworkException>()
            .having((e) => e.failures.length, 'failures.length', 3)),
      );
      repo.dispose();
    });

    test('连接异常（离线）同样按顺序回退到下一个候选', () async {
      final repo = RemoteTimetableRepository(
        client: MockClient((req) async => throw Exception('offline')),
        urls: [
          Uri.parse('https://a.example.com/x.json'),
          Uri.parse('https://b.example.com/x.json'),
        ],
      );

      await expectLater(repo.loadTimetable(), throwsA(isA<TimetableNetworkException>()));
      repo.dispose();
    });
  });

  group('SyncTimetableRepository 网络优先 + 本地回退', () {
    test('网络可用时返回线上数据', () async {
      final repo = SyncTimetableRepository(
        client: MockClient((req) async => _ok(_validJson)),
        cache: _MemCache(),
      );

      final data = await repo.loadTimetable();
      expect(data.meta.className, contains('2615'));
      expect(data.courses, isNotEmpty);
      repo.dispose();
    });

    test('网络失败时自动回退打包的 asset 课表', () async {
      final repo = SyncTimetableRepository(
        client: MockClient((req) async => http.Response('gateway timeout', 504)),
        cache: _MemCache(),
      );

      final data = await repo.loadTimetable();
      // asset 里的真实数据：19 周、15 门课程
      expect(data.meta.totalWeeks, 19);
      expect(data.courses.length, 15);
      repo.dispose();
    });

    test('联网成功后缓存落盘；离线时返回缓存的新数据而不丢', () async {
      final cache = _MemCache();
      // 线上数据比 asset 新（updated 日期更晚、课程更多）。
      final newerJson = _jsonWithUpdated(_validJson, '2099-01-01');
      final okClient = MockClient((req) async => _ok(newerJson));
      final repo = SyncTimetableRepository(client: okClient, cache: cache);

      // 第一次：联网成功，数据应写入缓存。
      final online = await repo.loadTimetable();
      expect(repo.usingFallback.value, isFalse);
      expect(cache.raw, isNotNull);
      expect(online.meta.updated, '2099-01-01');

      // 第二次：断网，必须仍返回刚才拉到的新数据（不回退旧 asset）。
      final offlineRepo = SyncTimetableRepository(
        client: MockClient((req) async => throw Exception('offline')),
        cache: cache,
      );
      final offline = await offlineRepo.loadTimetable();
      expect(offlineRepo.usingFallback.value, isTrue);
      expect(offline.meta.updated, '2099-01-01');
      offlineRepo.dispose();
      repo.dispose();
    });

    test('离线且缓存损坏时回退打包的 asset', () async {
      final repo = SyncTimetableRepository(
        client: MockClient((req) async => throw Exception('offline')),
        cache: _MemCache(raw: '{not valid json'),
      );

      final data = await repo.loadTimetable();
      expect(data.meta.totalWeeks, 19);
      expect(data.courses.length, 15);
      repo.dispose();
    });

    test('离线且缓存比打包 asset 旧时，取较新的 asset', () async {
      final olderCache = _MemCache(
        raw: _jsonWithUpdated(_validJson, '2000-01-01'),
      );
      final repo = SyncTimetableRepository(
        client: MockClient((req) async => throw Exception('offline')),
        cache: olderCache,
      );

      final data = await repo.loadTimetable();
      // asset 的 updated 一定晚于 2000-01-01，应胜出。
      expect(data.meta.updated, isNot('2000-01-01'));
      repo.dispose();
    });
  });
}

/// 测试用内存缓存：可预置内容，[raw] 记录最近一次写入。
class _MemCache implements TimetableCache {
  _MemCache({this.raw});
  String? raw;

  @override
  Future<String?> read() async => raw;

  @override
  Future<void> write(String raw) async => this.raw = raw;
}

/// 把 JSON 里的 meta.updated 替换成指定日期（测试比较新旧用）。
String _jsonWithUpdated(String raw, String updated) {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final meta = Map<String, dynamic>.from(json['meta'] as Map<String, dynamic>);
  meta['updated'] = updated;
  json['meta'] = meta;
  return jsonEncode(json);
}
