import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/features/campus/lostfound/lost_found_editor_page.dart';
import 'package:yuki_blog_app/features/campus/lostfound/lost_found_list_page.dart';

import '../support/campus_fixtures.dart';

Future<void> _pumpList(WidgetTester tester, CampusServices services) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: LostFoundListPage(services: services)),
  );
  // 首帧是 loading（无限动画），别用 pumpAndSettle。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

void main() {
  testWidgets('列表只显示进行中的帖子', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    expect(find.text('校园卡丢了'), findsOneWidget);
    expect(find.text('捡到一把黑色雨伞'), findsOneWidget);
    expect(find.text('白色无线耳机丢了'), findsOneWidget);
    // lf_3 已关闭，不该出现。
    expect(find.text('体育馆捡到一串钥匙'), findsNothing);

    // 切到「寻物」后只剩两条。
    await tester.tap(find.widgetWithText(ChoiceChip, '寻物'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('校园卡丢了'), findsOneWidget);
    expect(find.text('捡到一把黑色雨伞'), findsNothing);
  });

  testWidgets('点卡片进详情，标题与联系方式都在', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    await tester.tap(find.text('校园卡丢了'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('lf-detail-title'))).data,
      '校园卡丢了',
    );
    expect(find.text('三饭二楼'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('lf-detail-contact'))).data,
      '13800001111',
    );
  });

  testWidgets('自己的帖子能标记已找回，返回后列表里就没有了', (tester) async {
    final services = await testServices();
    await _pumpList(tester, services);

    await tester.tap(find.text('校园卡丢了'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lf-close')));
    await tester.pumpAndSettle();

    // 详情原地变成已完成，操作栏收起。
    expect(find.text('已完成'), findsOneWidget);
    expect(find.byKey(const Key('lf-close')), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('校园卡丢了'), findsNothing);
  });

  testWidgets('发布带图的信息，图片跟着帖子一起入库', (tester) async {
    final services = await testServices();

    final jpeg = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 16, height: 16), quality: 80),
    );

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
                      builder: (_) => LostFoundEditorPage(
                        services: services,
                        pickBytes: () async => [jpeg],
                      ),
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

    await tester.enterText(find.byKey(const Key('lf-title')), '捡到一张饭卡');
    await tester.enterText(
      find.byKey(const Key('lf-description')),
      '二饭门口捡到的，卡面贴着贴纸。',
    );
    await tester.enterText(find.byKey(const Key('lf-location')), '二饭门口');
    await tester.enterText(find.byKey(const Key('lf-contact')), '微信 abc_123');

    await tester.tap(find.text('选择图片'));
    await tester.pump();
    // 压缩走 compute（真 isolate），fake async 不推进真实时间，得放开跑。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lf-submit')));
    await tester.pumpAndSettle();

    expect(result, isTrue);

    final page = await services.lostFound.list();
    expect(page.items.first.title, '捡到一张饭卡');
    expect(page.items.first.imageIds.length, 1);
  });
}
