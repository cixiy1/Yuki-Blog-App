import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/features/campus/forms/form_builder_page.dart';
import 'package:yuki_blog_app/features/campus/forms/form_list_page.dart';
import 'package:yuki_blog_app/features/campus/forms/form_summary_page.dart';

import '../support/campus_fixtures.dart';

Future<void> _pumpList(WidgetTester tester, CampusServices services) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: FormListPage(services: services)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('列表只给进行中的表，点进去能看到题目', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    expect(find.text('教材选购登记'), findsOneWidget);
    expect(find.text('入党申请书材料收集'), findsNothing);

    await tester.tap(find.text('教材选购登记'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('fm-detail-title'))).data,
      '教材选购登记',
    );
    expect(find.text('1. 姓名'), findsOneWidget);
    expect(find.text('已收 2/50'), findsOneWidget);
    expect(find.byKey(const Key('fm-fill')), findsOneWidget);
  });

  testWidgets('漏填提交被拦，补齐后详情显示已提交', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    await tester.tap(find.text('教材选购登记'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fm-fill')));
    await tester.pumpAndSettle();

    // 什么都不填直接提交，校验把必填项一条条列出来。
    await tester.tap(find.byKey(const Key('ff-submit')));
    await _settle(tester);
    expect(find.byKey(const Key('ff-error')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('ff-f_1')), '张小明');
    await tester.enterText(find.byKey(const Key('ff-f_2')), '20250101');
    await tester.tap(find.byKey(const Key('ff-f_3-o_1')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('ff-f_4-o_4')));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('ff-f_5')), '2');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ff-submit')));
    await tester.pumpAndSettle();

    expect(find.text('我已提交'), findsOneWidget);
    expect(find.text('已收 3/50'), findsOneWidget);

    final list = await services.forms.list(filter: 'todo');
    expect(list.items.map((f) => f.title), isNot(contains('教材选购登记')));
  });

  testWidgets('建一张表：填标题与题目后出现在「我建的」', (tester) async {
    final services = await testServices(loginAs: '20250102');

    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: FormBuilderPage(services: services)),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('fm-title')), '国庆去向登记');
    // 默认已有一道单行文本题，填上标题即可。
    await tester.enterText(find.byKey(const Key('fm-label-0')), '假期去向');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fm-builder-submit')));
    await tester.pumpAndSettle();

    final mine = await services.forms.list(filter: 'mine');
    final created = mine.items.firstWhere((f) => f.title == '国庆去向登记');
    expect(created.fields, hasLength(1));
    expect(created.fields.first.label, '假期去向');
  });

  testWidgets('汇总页出统计与明细，导出 CSV 交给保存器', (tester) async {
    final services = await testServices(loginAs: '20250102');
    final form = await services.forms.detail('fm_1');

    String? savedName;
    String? savedContent;
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: FormSummaryPage(
          services: services,
          form: form,
          // 真实现会写系统临时目录，widget 测试里做真 I/O 会卡住 fake async。
          saveFile: ({required fileName, required content}) async {
            savedName = fileName;
            savedContent = content;
            return '/tmp/$fileName';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已收 2 / 50'), findsOneWidget);

    await tester.tap(find.text('明细'));
    await tester.pumpAndSettle();
    expect(find.text('陈佳仪'), findsWidgets);
    expect(find.text('周立'), findsWidgets);

    await tester.tap(find.byKey(const Key('fm-export')));
    await tester.pumpAndSettle();

    expect(savedName, endsWith('.csv'));
    expect(savedContent, isNotNull);
    expect(savedContent, contains('提交人,学号,班级,提交时间,姓名'));
    expect(savedContent, contains('陈佳仪'));
    expect(savedContent, contains('高等数学（上）'));

    final dialogText = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .join('\n');
    expect(dialogText, contains('CSV 存到了'));
    expect(dialogText, contains('/tmp/$savedName'));

    // 关掉弹窗，别把路由留在树上。
    await tester.tap(find.text('好'));
    await tester.pumpAndSettle();
  });
}
