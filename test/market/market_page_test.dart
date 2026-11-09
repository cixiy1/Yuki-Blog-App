import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/features/campus/market/market_editor_page.dart';
import 'package:yuki_blog_app/features/campus/market/market_list_page.dart';

import '../support/campus_fixtures.dart';

Future<void> _pumpList(WidgetTester tester, CampusServices services) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: MarketListPage(services: services)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('列表只显示在售物品，分类筛选生效', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    expect(find.text('《数据结构》教材 第 2 版'), findsOneWidget);
    expect(find.text('通勤自行车'), findsOneWidget);
    // mk_6 已售出，不该出现。
    expect(find.text('考研英语真题（已售）'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '数码电子'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('蓝牙耳机（半入耳）'), findsOneWidget);
    expect(find.text('通勤自行车'), findsNothing);
  });

  testWidgets('点卡片进详情，价格与联系方式都在', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    await tester.tap(find.text('宿舍小台灯'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('mk-detail-title'))).data,
      '宿舍小台灯',
    );
    expect(find.text('¥20.00'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('mk-detail-contact'))).data,
      '13700003333',
    );
  });

  testWidgets('自己的物品标记已售出，返回后列表里就没有了', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    await tester.tap(find.text('通勤自行车'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mk-sold')));
    await tester.pumpAndSettle();

    expect(find.text('已售出'), findsOneWidget);
    expect(find.byKey(const Key('mk-sold')), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('通勤自行车'), findsNothing);
  });

  testWidgets('发布时元转分：填 12.5 存成 1250', (tester) async {
    final services = await testServices();

    bool? result;
    tester.view.physicalSize = const Size(900, 2400);
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
                      builder: (_) => MarketEditorPage(services: services),
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

    await tester.enterText(find.byKey(const Key('mk-title')), '机械键盘');
    await tester.enterText(find.byKey(const Key('mk-price')), '12.5');
    await tester.enterText(
      find.byKey(const Key('mk-description')),
      '青轴，键帽没掉字。',
    );
    await tester.enterText(find.byKey(const Key('mk-contact')), '微信 kb_01');

    await tester.tap(find.byKey(const Key('mk-submit')));
    await tester.pumpAndSettle();

    expect(result, isTrue);

    final page = await services.market.list();
    expect(page.items.first.priceCents, 1250);
    expect(page.items.first.title, '机械键盘');
  });
}
