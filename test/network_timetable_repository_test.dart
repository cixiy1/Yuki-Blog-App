import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myclass/core/network_timetable_repository.dart';

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
      );

      final data = await repo.loadTimetable();
      expect(data.meta.className, contains('2615'));
      expect(data.courses, isNotEmpty);
      repo.dispose();
    });

    test('网络失败时自动回退打包的 asset 课表', () async {
      final repo = SyncTimetableRepository(
        client: MockClient((req) async => http.Response('gateway timeout', 504)),
      );

      final data = await repo.loadTimetable();
      // asset 里的真实数据：19 周、15 门课程
      expect(data.meta.totalWeeks, 19);
      expect(data.courses.length, 15);
      repo.dispose();
    });
  });
}
