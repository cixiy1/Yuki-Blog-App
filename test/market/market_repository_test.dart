import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/models/campus/market_item.dart';

import '../support/campus_fixtures.dart';

/// 二手闲置仓储层：接口口径与权限边界。
void main() {
  test('默认列表只给在售物品，按发布时间倒序', () async {
    final services = await testServices();
    final page = await services.market.list();

    // mk_6 已售出，不该出现。
    expect(page.items.map((e) => e.id), ['mk_1', 'mk_2', 'mk_3', 'mk_4', 'mk_5']);
    expect(page.items.every((e) => e.isOnSale), isTrue);
  });

  test('按分类筛选只返回该类', () async {
    final services = await testServices();
    final page = await services.market.list(category: MarketCategory.book);

    expect(page.items.length, 1);
    expect(page.items.first.title, '《数据结构》教材 第 2 版');
  });

  test('按价格升序排列', () async {
    final services = await testServices();
    final page = await services.market.list(sort: MarketSort.priceAsc);

    final prices = page.items.map((e) => e.priceCents).toList();
    expect(prices, [1500, 2000, 3500, 8000, 12000]);
  });

  test('关键词命中标题或描述', () async {
    final services = await testServices();
    final page = await services.market.list(query: '台灯');

    expect(page.items.length, 1);
    expect(page.items.first.id, 'mk_2');
  });

  test('发布后出现在列表，金额按分存储', () async {
    final services = await testServices();
    final created = await services.market.create(
      title: '机械键盘',
      description: '青轴，键帽没掉字。',
      contact: '微信 kb_01',
      priceCents: 9900,
      condition: ItemCondition.good,
      category: MarketCategory.digital,
    );

    expect(created.priceCents, 9900);
    expect(created.isMine, isTrue);

    final page = await services.market.list();
    expect(page.items.first.id, created.id);
  });

  test('标记已售出后从列表消失', () async {
    final services = await testServices();

    final sold = await services.market.markSold('mk_5');
    expect(sold.status, MarketStatus.sold);

    final page = await services.market.list();
    expect(page.items.map((e) => e.id), isNot(contains('mk_5')));

    // 重复标记是状态冲突，不是静默成功。
    await expectLater(
      services.market.markSold('mk_5'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'ALREADY_SOLD'),
      ),
    );
  });

  test('改别人的物品被 403 挡下', () async {
    final services = await testServices(loginAs: '20250102');

    await expectLater(
      services.market.update('mk_1', title: '改个标题'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );
  });

  test('价格为负返回字段级错误', () async {
    final services = await testServices();

    await expectLater(
      services.market.create(
        title: '测试',
        description: '描述',
        contact: '13800001111',
        priceCents: -1,
        condition: ItemCondition.good,
        category: MarketCategory.other,
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_FAILED')
            .having((e) => e.fieldErrors.containsKey('priceCents'),
                '带 priceCents 错误', isTrue),
      ),
    );
  });

  test('删除后详情返回 404', () async {
    final services = await testServices();

    await services.market.remove('mk_5');

    await expectLater(
      services.market.detail('mk_5'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
    );
  });
}
