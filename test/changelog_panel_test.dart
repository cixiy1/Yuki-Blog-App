import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/asset_timetable_repository.dart';
import 'package:yuki_blog_app/features/schedule/schedule_page.dart';
import 'package:yuki_blog_app/features/schedule/widgets/changelog_panel.dart';
import 'package:yuki_blog_app/models/timetable.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

/// 「数据更新历」的折叠行为与滚动行为。
///
/// 这几条断言源自一个真实故障：面板原来是「限高 320px + 内部滚动」，
/// 51 条记录全量构建，且鼠标停在框上时滚轮被内部滚动框独占 ——
/// 页面从课表往下滑到更新历就一动不动（外页 offset 1279→1279，内层 0→300）。
/// Flutter 不做浏览器那样的滚动链传递，所以内层滚动必须去掉。
void main() {
  final data = TimetableData.fromRawJson(
      File('assets/data/schedule-2615.json').readAsStringSync());
  final entries = data.meta.changelog;

  /// 更新历的单条记录是私有组件，按运行时类型数行数。
  Finder changelogRows() =>
      find.byWidgetPredicate((w) => '${w.runtimeType}' == '_ChangelogRow');

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChangelogPanel(meta: data.meta),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('默认只建最新 4 条，展开后显示全部', (tester) async {
    expect(entries.length, greaterThan(4), reason: '样本数据要够多才能测折叠');
    await pumpPanel(tester);

    expect(changelogRows(), findsNWidgets(ChangelogPanel.collapsedCount));
    expect(find.text('展开全部 ${entries.length} 条'), findsOneWidget);

    await tester.tap(find.text('展开全部 ${entries.length} 条'));
    await tester.pumpAndSettle();
    expect(changelogRows(), findsNWidgets(entries.length));
    expect(find.text('收起'), findsOneWidget);

    // 展开后「收起」掉到视口外，不先滚过去点不到。
    await tester.ensureVisible(find.text('收起'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(changelogRows(), findsNWidgets(ChangelogPanel.collapsedCount));
  });

  testWidgets('面板内部不再有滚动视图（否则会独占滚轮事件）', (tester) async {
    await pumpPanel(tester);
    expect(
      find.descendant(
        of: find.byType(ChangelogPanel),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
  });

  testWidgets('指针停在更新历上滚动，页面照常滚动', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ImmersiveScaffold(
          title: '动态课程表',
          body: SchedulePage(repository: InMemoryTimetableRepository(data)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final outer =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    outer.jumpTo(outer.maxScrollExtent);
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byType(ChangelogPanel));
    expect(panel.top, lessThan(600), reason: '滚到底后更新历应进入视口');

    final pointer = TestPointer(1, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pointer.hover(panel.center));
    final before = outer.pixels;
    for (var i = 0; i < 3; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -60)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(
      outer.pixels,
      lessThan(before),
      reason: '鼠标停在更新历上时，滚轮必须交给页面而不是被面板吃掉',
    );
  });
}
