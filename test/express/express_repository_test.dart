import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/models/campus/express_task.dart';

import '../support/campus_fixtures.dart';

/// 快递代取：可见性、取件码脱敏、状态机与权限。
void main() {
  test('默认列表给进行中的，别班的「仅本班」看不到', () async {
    final services = await testServices();
    final page = await services.express.list();

    // ex_2 是软件2616 周立发的仅本班委托，张小明不该看到。
    expect(page.items.map((e) => e.id), ['ex_1', 'ex_3']);
    expect(page.items.every((e) => e.status.isActive), isTrue);
  });

  test('待接单列表不含自己发的', () async {
    final services = await testServices();
    await services.express.create(
      station: '菜鸟驿站（北门）',
      pickupCode: '1-2-3',
      deliverTo: '3栋412',
      rewardCents: 300,
      deadline: DateTime.now().add(const Duration(hours: 3)),
    );

    final page = await services.express.list(status: 'pending');
    expect(page.items.map((e) => e.creatorName), isNot(contains('张小明')));
  });

  test('取件码只对接单人与发布者可见', () async {
    final services = await testServices();

    final before = await services.express.detail('ex_1');
    expect(before.pickupCode, ExpressTask.kMaskedPickupCode);

    final accepted = await services.express.accept('ex_1');
    expect(accepted.isCourier, isTrue);
    expect(accepted.pickupCode, '8-2-3021');
  });

  test('不能接自己发的单', () async {
    final services = await testServices();
    final mine = await services.express.create(
      station: '菜鸟驿站（北门）',
      pickupCode: '1-2-3',
      deliverTo: '3栋412',
      rewardCents: 300,
      deadline: DateTime.now().add(const Duration(hours: 3)),
    );

    await expectLater(
      services.express.accept(mine.id),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );
  });

  test('被接走后第二个人接会 409', () async {
    final services = await testServices();
    final task = await services.express.create(
      station: '菜鸟驿站（北门）',
      pickupCode: '1-2-3',
      deliverTo: '3栋412',
      rewardCents: 300,
      deadline: DateTime.now().add(const Duration(hours: 3)),
    );

    await signInAs(services, '20250102');
    await services.express.accept(task.id);

    await signInAs(services, '20250103');
    await expectLater(
      services.express.accept(task.id),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'NOT_PENDING'),
      ),
    );
  });

  test('只有接单人能标记送达，只有发布者能确认完成', () async {
    final services = await testServices();
    final task = await services.express.create(
      station: '京东快递（西门）',
      pickupCode: '9-9-9',
      deliverTo: '5栋207',
      rewardCents: 200,
      deadline: DateTime.now().add(const Duration(hours: 2)),
    );

    await signInAs(services, '20250102');
    await services.express.accept(task.id);

    // 发布者不能替接单人点送达。
    await signInAs(services, '20250101');
    await expectLater(
      services.express.markDelivered(task.id),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );

    await signInAs(services, '20250102');
    await services.express.markDelivered(task.id);

    // 接单人不能替发布者确认完成。
    await expectLater(
      services.express.complete(task.id),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );

    await signInAs(services, '20250101');
    final done = await services.express.complete(task.id);
    expect(done.status, ExpressStatus.completed);
    expect(done.completedAt, isNotNull);
  });

  test('取消后落到已完成分组，接单人收到消息', () async {
    final services = await testServices();
    final task = await services.express.create(
      station: '菜鸟驿站（南门）',
      pickupCode: '7-7-7',
      deliverTo: '2栋315',
      rewardCents: 250,
      deadline: DateTime.now().add(const Duration(hours: 2)),
    );

    await signInAs(services, '20250102');
    await services.express.accept(task.id);

    await signInAs(services, '20250101');
    final cancelled = await services.express.cancel(task.id);
    expect(cancelled.status, ExpressStatus.cancelled);

    final finished = await services.express.list(status: 'finished');
    expect(finished.items.map((e) => e.id), contains(task.id));

    await signInAs(services, '20250102');
    final inbox = await services.messages.list();
    expect(inbox.items.any((m) => m.title == '任务被取消了'), isTrue);
  });
}
