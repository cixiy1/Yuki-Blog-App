import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/json_store_memory.dart';

void main() {
  test('写入后能原样读出', () async {
    final store = MemoryJsonStore();
    await store.write('db', {
      'a': 1,
      'list': [
        {'x': 'y'},
      ],
    });

    final value = await store.read('db');
    expect(value, isNotNull);
    expect(value!['a'], 1);
    expect((value['list'] as List).first['x'], 'y');
  });

  test('键不存在时返回 null 而不是抛异常', () async {
    final store = MemoryJsonStore();
    expect(await store.read('missing'), isNull);
  });

  test('重复写会整体覆盖旧值', () async {
    final store = MemoryJsonStore();
    await store.write('session', {'token': 'old', 'extra': 1});
    await store.write('session', {'token': 'new'});

    final value = await store.read('session');
    expect(value!['token'], 'new');
    expect(value.containsKey('extra'), isFalse, reason: '覆盖写不应保留旧字段');
  });
}
