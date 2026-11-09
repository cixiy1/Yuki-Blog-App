import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/models/campus/lost_found_post.dart';

import '../support/campus_fixtures.dart';

/// 失物招领仓储层：走真实的 Mock 后端，验证接口口径而不是页面渲染。
void main() {
  test('默认列表只给进行中的帖子，按发布时间倒序', () async {
    final services = await testServices();
    final page = await services.lostFound.list();

    // 种子里 lf_3 已关闭，不该出现。
    expect(page.items.map((e) => e.id), ['lf_1', 'lf_2', 'lf_4']);
    expect(page.items.every((e) => e.status == PostStatus.open), isTrue);
  });

  test('按类型筛选只返回寻物', () async {
    final services = await testServices();
    final page = await services.lostFound.list(type: LostFoundType.lost);

    expect(page.items.map((e) => e.id), ['lf_1', 'lf_4']);
  });

  test('按地点模糊筛选命中一条', () async {
    final services = await testServices();
    final page = await services.lostFound.list(location: '图书馆');

    expect(page.items.length, 1);
    expect(page.items.first.title, '捡到一把黑色雨伞');
  });

  test('自己发的帖子 isMine 为真，别人看为假', () async {
    final mineServices = await testServices();
    final mine = await mineServices.lostFound.detail('lf_1');
    expect(mine.isMine, isTrue);

    final otherServices = await testServices(loginAs: '20250102');
    final other = await otherServices.lostFound.detail('lf_1');
    expect(other.isMine, isFalse);
  });

  test('发布后能在列表里查到，作者是自己', () async {
    final services = await testServices();
    final created = await services.lostFound.create(
      type: LostFoundType.found,
      title: '捡到一张饭卡',
      description: '在二饭门口捡到，卡面有贴纸。',
      location: '二饭门口',
      contact: '微信 abc_123',
      occurredAt: DateTime.now(),
    );

    expect(created.isMine, isTrue);
    expect(created.authorName, '张小明');

    final page = await services.lostFound.list();
    expect(page.items.first.id, created.id);
  });

  test('改别人的帖子被 403 挡下', () async {
    final services = await testServices(loginAs: '20250102');

    await expectLater(
      services.lostFound.update('lf_1', title: '改个标题'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.code, 'code', 'FORBIDDEN'),
      ),
    );
  });

  test('标记完成后从列表消失，但详情仍可读', () async {
    final services = await testServices();

    final closed = await services.lostFound.close('lf_1');
    expect(closed.status, PostStatus.closed);

    final page = await services.lostFound.list();
    expect(page.items.map((e) => e.id), isNot(contains('lf_1')));

    final detail = await services.lostFound.detail('lf_1');
    expect(detail.isOpen, isFalse);
  });

  test('删除后详情返回 404', () async {
    final services = await testServices();

    await services.lostFound.remove('lf_1');

    await expectLater(
      services.lostFound.detail('lf_1'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
    );
  });

  test('标题为空时返回字段级错误', () async {
    final services = await testServices();

    await expectLater(
      services.lostFound.create(
        type: LostFoundType.lost,
        title: '   ',
        description: '描述',
        location: '地点',
        contact: '13800001111',
        occurredAt: DateTime.now(),
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_FAILED')
            .having((e) => e.fieldErrors.containsKey('title'), '带 title 错误', isTrue),
      ),
    );
  });
}
