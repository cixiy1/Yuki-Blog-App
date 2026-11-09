import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/features/campus/express/express_editor_page.dart';
import 'package:yuki_blog_app/features/campus/express/express_list_page.dart';

import '../support/campus_fixtures.dart';

Future<void> _pumpList(WidgetTester tester, CampusServices services) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: ExpressListPage(services: services)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('接单后取件码从脱敏变成明文', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    expect(find.text('菜鸟驿站（北门）'), findsOneWidget);
    expect(find.text('取件码接单后可见'), findsOneWidget);

    await tester.tap(find.text('菜鸟驿站（北门）'));
    await tester.pumpAndSettle();

    expect(find.text('接单后可见'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ex-accept')));
    await tester.pumpAndSettle();

    expect(find.text('8-2-3021'), findsOneWidget);
    // 接完单按钮换成「标记已送达」。
    expect(find.byKey(const Key('ex-deliver')), findsOneWidget);
    expect(find.byKey(const Key('ex-accept')), findsNothing);
  });

  testWidgets('「我接的」里能看到自己接的单', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    await tester.tap(find.widgetWithText(ChoiceChip, '我接的'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('菜鸟驿站（南门）'), findsOneWidget);
    expect(find.text('已送达'), findsOneWidget);
  });

  testWidgets('发布代取后出现在待接单里', (tester) async {
    final services = await testServices();

    bool? result;
    tester.view.physicalSize = const Size(900, 2600);
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
                      builder: (_) => ExpressEditorPage(services: services),
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

    await tester.enterText(find.byKey(const Key('ex-station')), '顺丰驿站（东门）');
    await tester.enterText(find.byKey(const Key('ex-code')), '5-1-8888');
    await tester.enterText(find.byKey(const Key('ex-deliver-to')), '6栋101');
    await tester.enterText(find.byKey(const Key('ex-reward')), '2.5');

    await tester.tap(find.byKey(const Key('ex-submit')));
    await tester.pumpAndSettle();

    expect(result, isTrue);

    final page = await services.express.list(status: 'all', onlyMine: true);
    expect(page.items.first.station, '顺丰驿站（东门）');
    expect(page.items.first.rewardCents, 250);
  });
}
