import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/api/api_paths.dart';
import 'package:yuki_blog_app/core/api/campus_db_store.dart';
import 'package:yuki_blog_app/core/api/mock/mock_api_client.dart';
import 'package:yuki_blog_app/core/api/mock/mock_request.dart';
import 'package:yuki_blog_app/models/campus/json_utils.dart';

import '../support/mock_fixtures.dart';

void main() {
  test('latency 为零时不额外等待', () async {
    final api = newMockApi();
    addTearDown(api.dispose);
    await api.ensureLoaded();

    final sw = Stopwatch()..start();
    try {
      await api.get(ApiPaths.me);
    } on ApiException {
      // 未登录必然 401，这里只关心耗时。
    }
    sw.stop();

    // 未登录会立刻 401，重点是「没有被人为延迟拖住」。
    expect(sw.elapsedMilliseconds, lessThan(200));
  });

  test('注入 500 时抛对应错误', () async {
    final api = newMockApi(
      injector: (method, path) =>
          const MockError(500, 'INTERNAL', '服务异常'),
    );
    addTearDown(api.dispose);

    expect(
      () => api.get(ApiPaths.me),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 500)
          .having((e) => e.message, 'message', '服务异常')),
    );
  });

  test('注入 401 时触发 onUnauthorized', () async {
    // 只让 /auth/me 失败，否则连登录都会被注入器拦掉。
    final api = newMockApi(
      injector: (method, path) => path == ApiPaths.me
          ? const MockError(401, 'UNAUTHORIZED', '过期')
          : null,
    );
    addTearDown(api.dispose);
    await loginAs(api);

    var called = 0;
    api.onUnauthorized = () => called++;

    await expectLater(api.get(ApiPaths.me), throwsA(isA<ApiException>()));
    expect(called, 1);
  });

  test('20 个并发写全部落库，一条不丢', () async {
    final api = newMockApi();
    addTearDown(api.dispose);
    await api.ensureLoaded();

    final before = api.db.users.length;
    await Future.wait([
      for (var i = 0; i < 20; i++)
        api.post(ApiPaths.register, body: {
          'studentId': '2026010${i.toString().padLeft(2, '0')}',
          'password': '123456',
          'name': '测试$i',
          'className': '软件2615',
        }),
    ]);

    expect(api.db.users.length, before + 20);
    // 学号不能重复，顺手验证没有覆盖成同一个。
    expect(
      api.db.users.map((u) => u['studentId']).toSet().length,
      api.db.users.length,
    );
  });

  test('flush 后换一个 client 重新加载，数据一致', () async {
    final store = MemoryCampusDbStore();
    final first = MockApiClient(store: store, latency: Duration.zero);
    await first.ensureLoaded();
    await first.post(ApiPaths.register, body: {
      'studentId': '20260188',
      'password': '123456',
      'name': '持久化',
      'className': '软件2615',
    });
    await first.flush();
    final count = first.db.users.length;
    first.dispose();

    final second = MockApiClient(store: store, latency: Duration.zero);
    addTearDown(second.dispose);
    await second.ensureLoaded();

    expect(second.db.users.length, count);
  });

  test('库里 schemaVersion 不匹配时重新播种', () async {
    final store = MemoryCampusDbStore({
      'schemaVersion': 999,
      'users': <Map<String, dynamic>>[],
    });
    final api = MockApiClient(store: store, latency: Duration.zero);
    addTearDown(api.dispose);
    await api.ensureLoaded();

    expect(api.db.users.length, greaterThanOrEqualTo(3));
    expect(api.db.schemaVersion, 1, reason: '播种后应回写当前版本');
  });

  test('flush 等待写盘完成', () async {
    final store = MemoryCampusDbStore();
    final api = MockApiClient(store: store, latency: Duration.zero);
    addTearDown(api.dispose);
    await api.ensureLoaded();

    await api.post(ApiPaths.register, body: {
      'studentId': '20260199',
      'password': '123456',
      'name': '刷盘',
      'className': '软件2615',
    });
    await api.flush();

    expect(store.raw, isNotNull);
    final saved = asMapList(store.raw!['users']);
    expect(
      saved.any((u) => u['studentId'] == '20260199'),
      isTrue,
      reason: 'flush 之后磁盘快照必须包含新用户',
    );
  });

  test('同一份种子建两次，数据量一致（播种幂等）', () async {
    final store = MemoryCampusDbStore();
    final a = MockApiClient(store: store, latency: Duration.zero);
    await a.ensureLoaded();
    final counts = {
      'users': a.db.users.length,
      'lostFound': a.db.lostFound.length,
      'market': a.db.market.length,
    };
    a.dispose();

    final b = MockApiClient(store: store, latency: Duration.zero);
    addTearDown(b.dispose);
    await b.ensureLoaded();

    expect(b.db.users.length, counts['users']);
    expect(b.db.lostFound.length, counts['lostFound']);
    expect(b.db.market.length, counts['market']);
  });
}
