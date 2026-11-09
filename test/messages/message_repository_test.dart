import 'package:flutter_test/flutter_test.dart';

import '../support/campus_fixtures.dart';

void main() {
  test('收件箱按时间倒序返回，且只含自己的消息', () async {
    final services = await testServices();
    final page = await services.messages.list();

    expect(page.items.length, 5);
    expect(page.items.first.id, 'ms_1', reason: '种子最新的是 3 小时前那条接单提醒');
    for (final message in page.items) {
      expect(message.userId, 'u_1001');
    }
  });

  test('unreadOnly 只返回未读', () async {
    final services = await testServices();
    final page = await services.messages.list(unreadOnly: true);

    expect(page.items.length, 3);
    expect(page.items.every((m) => !m.read), isTrue);
  });

  test('标记已读后未读数减一', () async {
    final services = await testServices();
    expect(await services.messages.unreadCount(), 3);

    final newCount = await services.messages.markRead('ms_1');
    expect(newCount, 2);
    expect(await services.messages.unreadCount(), 2);

    await services.messages.markAllRead();
    expect(await services.messages.unreadCount(), 0);
  });
}
