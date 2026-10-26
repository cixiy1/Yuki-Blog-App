import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';
import 'package:yuki_blog_app/features/schedule/widgets/timetable_grid.dart';
import 'package:yuki_blog_app/models/timetable.dart';

void main() {
  final data = TimetableData.fromRawJson(
    File('assets/data/schedule-2615.json').readAsStringSync(),
  );
  final resolver = TimetableResolver(data);
  final week = resolver.currentWeek();
  final schedule = resolver.resolve(week);

  /// 窄视口（默认 400）：7 天列撑出横向滚动，才能验证行标跟着内容滚。
  Future<void> pumpGrid(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimetableGrid(
              schedule: schedule,
              weekMonday: DateTime(2026, 10, 26),
              todayWeekday: 1,
              selectedKey: null,
              onSelectEntry: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder horizontalBody() => find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
  );

  testWidgets('显示不全时左右行标都在，且都内联在滚动里', (tester) async {
    await pumpGrid(tester); // 400 宽，放不下

    // 每行：行首一个 + 行尾一个
    expect(
      find.byType(SlotLabelCell),
      findsNWidgets(schedule.rows.length * 2),
      reason: '放不下时左右各一列行标',
    );

    final firstLabel = schedule.rows.first.label;
    // 首行标签在左右两端各出现一次
    expect(find.text(firstLabel), findsNWidgets(2));
    final left = find.text(firstLabel).first;
    final right = find.text(firstLabel).last;
    expect(
      tester.getTopLeft(left).dx,
      lessThan(tester.getTopLeft(right).dx),
      reason: '右列行标应在左列右侧（行尾）',
    );
  });

  testWidgets('横向滚动时，行标随内容一起滚动', (tester) async {
    await pumpGrid(tester);

    final body = horizontalBody();
    expect(body, findsOneWidget, reason: '整张网格应在一个横向滚动视图里');
    final position = tester.state<ScrollableState>(body).position;
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: '窄屏下 7 天列应撑出横向滚动',
    );

    // 首行左列行标在最左侧（内容 x=0 处）
    final firstLabel = find.byType(SlotLabelCell).first;
    final before = tester.getTopLeft(firstLabel);

    await tester.drag(body, const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0), reason: '表体确实滚走了');
    // 行标内联在行里，应当跟着内容一起向左移，而不是钉死在外层
    final after = tester.getTopLeft(firstLabel);
    expect(after.dx, lessThan(before.dx), reason: '行标应随内容一起滚动');
  });

  testWidgets('宽屏放得下时只有左侧行标，且不横向滚动', (tester) async {
    await pumpGrid(tester, size: const Size(900, 900));

    expect(
      find.byType(SlotLabelCell),
      findsNWidgets(schedule.rows.length),
      reason: '放得下时只保留左侧一列行标',
    );
    expect(
      tester
          .state<ScrollableState>(horizontalBody())
          .position
          .maxScrollExtent,
      0,
      reason: '这个视口能铺下 7 天，不该横向滚动',
    );
  });

  testWidgets('窄屏需要横向滚动', (tester) async {
    await pumpGrid(tester); // 400 宽

    expect(
      tester
          .state<ScrollableState>(horizontalBody())
          .position
          .maxScrollExtent,
      greaterThan(0),
    );
  });
}
