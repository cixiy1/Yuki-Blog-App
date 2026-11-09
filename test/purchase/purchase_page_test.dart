import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/core/campus/purchase_repository.dart';
import 'package:yuki_blog_app/features/campus/purchase/purchase_detail_page.dart';
import 'package:yuki_blog_app/features/campus/purchase/purchase_editor_page.dart';
import 'package:yuki_blog_app/features/campus/purchase/purchase_list_page.dart';
import 'package:yuki_blog_app/models/campus/purchase_task.dart';

import '../support/campus_fixtures.dart';

Future<void> _pumpList(WidgetTester tester, CampusServices services) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: PurchaseListPage(services: services)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('待接单里没有自己发的，切到「我发布的」才看得到', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    expect(find.text('暂时没有要代买的'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '我发布的'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('帮带两杯奶茶'), findsOneWidget);

    await tester.tap(find.text('帮带两杯奶茶'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('pu-detail-title'))).data,
      '帮带两杯奶茶',
    );
    // 自己发的单不能自己接，但可以取消。
    expect(find.byKey(const Key('pu-accept')), findsNothing);
    expect(find.byKey(const Key('pu-cancel')), findsOneWidget);
  });

  testWidgets('完成后评价，三条星级可选并出现在评价区', (tester) async {
    final services = await testServices();
    final created = await services.purchases.create(
      title: '帮带一杯奶茶',
      fromPlace: '一饭二楼',
      toPlace: '3栋412',
      items: const [PurchaseDraftItem(name: '珍珠奶茶', qty: 1)],
      amountCents: 800,
      paymentMethod: PaymentMethod.wechat,
      deadline: DateTime.now().add(const Duration(hours: 3)),
    );

    await signInAs(services, '20250102');
    await services.purchases.accept(created.id);
    await services.purchases.markDelivered(created.id);

    await signInAs(services, '20250101');
    await services.purchases.complete(created.id);
    final task = await services.purchases.detail(created.id);

    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: PurchaseDetailPage(services: services, task: task)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pu-review')), findsOneWidget);

    await tester.tap(find.byKey(const Key('pu-review')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rv-star-3')));
    await tester.pump();
    expect(find.text('3 星 · 不加减分'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('rv-comment')), '东西没洒');
    await tester.tap(find.byKey(const Key('rv-submit')));
    await tester.pumpAndSettle();

    // 评价落地后按钮收起，评价区出现这条内容。
    expect(find.byKey(const Key('pu-review')), findsNothing);
    expect(find.text('东西没洒'), findsOneWidget);

    final detail = await services.purchases.detail(created.id);
    expect(detail.reviewedByMe, isTrue);
    expect(detail.myReview?.stars, 3);
  });

  testWidgets('发布代买：两样物品与金额都存对', (tester) async {
    final services = await testServices();

    bool? result;
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open-editor'),
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => PurchaseEditorPage(services: services),
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-editor')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pu-title')), '超市代买');
    await tester.enterText(find.byKey(const Key('pu-from')), '学校超市');
    await tester.enterText(find.byKey(const Key('pu-to')), '5栋207');
    await tester.enterText(find.byKey(const Key('pu-item-name-0')), '洗衣液');
    await tester.enterText(find.byKey(const Key('pu-item-qty-0')), '2');
    await tester.enterText(find.byKey(const Key('pu-amount')), '32');

    await tester.tap(find.byKey(const Key('pu-submit')));
    await tester.pumpAndSettle();

    expect(result, isTrue);

    final page = await services.purchases.list(status: 'all', onlyMine: true);
    final created = page.items.first;
    expect(created.title, '超市代买');
    expect(created.amountCents, 3200);
    expect(created.items.length, 1);
    expect(created.items.first.qty, 2);
  });
}
