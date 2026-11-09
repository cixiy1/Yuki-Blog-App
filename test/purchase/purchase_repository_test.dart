import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/core/campus/purchase_repository.dart';
import 'package:yuki_blog_app/models/campus/purchase_task.dart';

import '../support/campus_fixtures.dart';

/// 造一条刚发布、马上要用的代买单。
Future<PurchaseTask> _createTask(CampusServices services) =>
    services.purchases.create(
      title: '帮带一杯奶茶',
      fromPlace: '一饭二楼',
      toPlace: '3栋412',
      items: const [PurchaseDraftItem(name: '珍珠奶茶', qty: 1)],
      amountCents: 800,
      paymentMethod: PaymentMethod.wechat,
      deadline: DateTime.now().add(const Duration(hours: 3)),
    );

void main() {
  test('待接单列表不含自己发的', () async {
    final services = await testServices();

    final pending = await services.purchases.list(status: 'pending');
    expect(pending.items.any((e) => e.creatorName == '张小明'), isFalse);

    final mine = await services.purchases.list(status: 'all', onlyMine: true);
    expect(mine.items.map((e) => e.id), contains('pu_1'));
  });

  test('别班发的「仅本班」委托看不到', () async {
    final services = await testServices();

    // 周立是软件2616，发的仅本班委托只该 2616 的人看到。
    await signInAs(services, '20250105');
    final task = await services.purchases.create(
      title: '帮取一下外卖',
      fromPlace: '一饭门口',
      toPlace: '7栋201',
      items: const [PurchaseDraftItem(name: '外卖', qty: 1)],
      amountCents: 1500,
      paymentMethod: PaymentMethod.cash,
      deadline: DateTime.now().add(const Duration(hours: 2)),
    );

    await signInAs(services, '20250101');
    final page = await services.purchases.list(status: 'all');
    expect(page.items.map((e) => e.id), isNot(contains(task.id)));
  });

  test('接单 → 送达 → 完成，状态一路推进', () async {
    final services = await testServices();
    final task = await services.purchases.create(
      title: '帮带一杯奶茶',
      fromPlace: '一饭二楼',
      toPlace: '3栋412',
      items: const [PurchaseDraftItem(name: '珍珠奶茶', qty: 1)],
      amountCents: 800,
      paymentMethod: PaymentMethod.wechat,
      deadline: DateTime.now().add(const Duration(hours: 3)),
    );

    await signInAs(services, '20250102');
    final accepted = await services.purchases.accept(task.id);
    expect(accepted.status, PurchaseStatus.accepted);
    expect(accepted.isCourier, isTrue);

    await services.purchases.markDelivered(task.id);

    // 接单人不能替发布者确认完成。
    await expectLater(
      services.purchases.complete(task.id),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );

    await signInAs(services, '20250101');
    final done = await services.purchases.complete(task.id);
    expect(done.status, PurchaseStatus.completed);
    expect(done.canReview, isTrue);
  });

  test('完成双方各评一次，被评人信用分按星级变化', () async {
    final services = await testServices();
    final task = await _createTask(services);

    await signInAs(services, '20250102');
    await services.purchases.accept(task.id);
    await services.purchases.markDelivered(task.id);

    await signInAs(services, '20250101');
    await services.purchases.complete(task.id);

    final review = await services.purchases.submitReview(
      task.id,
      stars: 5,
      tags: const ['准时'],
      comment: '很快',
    );
    expect(review.stars, 5);
    expect(review.toUserName, '李思远');

    final detail = await services.purchases.detail(task.id);
    expect(detail.reviewedByMe, isTrue);
    expect(detail.myReview?.stars, 5);

    // 李思远原 88 分，五星 +2。
    await signInAs(services, '20250102');
    expect(services.session.user!.creditScore, 90);

    // 反过来评发布者，一星 -4：张小明 72 → 68。
    await services.purchases.submitReview(task.id, stars: 1);

    await signInAs(services, '20250101');
    expect(services.session.user!.creditScore, 68);

    final list = await services.purchases.reviews(task.id);
    expect(list.length, 2);
  });

  test('同一人重复评价被挡下', () async {
    final services = await testServices();

    await signInAs(services, '20250102');
    // pu_2 已完成且李思远已经评过。
    await expectLater(
      services.purchases.submitReview('pu_2', stars: 5),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'ALREADY_REVIEWED'),
      ),
    );
  });

  test('未完成的任务不能评价', () async {
    final services = await testServices();

    await expectLater(
      services.purchases.submitReview('pu_1', stars: 5),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'BAD_STATUS'),
      ),
    );
  });

  test('局外人不能评价', () async {
    final services = await testServices(loginAs: '20250103');

    await expectLater(
      services.purchases.submitReview('pu_2', stars: 5),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );
  });
}
