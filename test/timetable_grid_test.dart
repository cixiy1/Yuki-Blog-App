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

  /// 窄视口（默认 400）：7 天列必然撑出横向滚动，才能验证行标是固定的。
  Future<void> pumpGrid(WidgetTester tester, {Size size = const Size(400, 900)}) async {
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

  testWidgets('作息表左右两侧各有一列，条数与时段行一致', (tester) async {
    await pumpGrid(tester);

    // 每个时段行 ×2（左列 + 右列）
    expect(
      find.byType(SlotLabelCell),
      findsNWidgets(schedule.rows.length * 2),
      reason: '左右两边都要有作息表行标',
    );

    // 首行节次文字在左右两列各出现一次
    final firstLabel = schedule.rows.first.label;
    expect(find.text(firstLabel), findsNWidgets(2));
    if (schedule.rows.first.timeText.isNotEmpty) {
      expect(find.text(schedule.rows.first.timeText), findsNWidgets(2));
    }
  });

  testWidgets('横向滚动表体时，左右两列行标都不动', (tester) async {
    await pumpGrid(tester);

    final labels = find.byType(SlotLabelCell);
    final firstRow = schedule.rows.first.label;
    // 同一行的两个行标：左列在最前，右列在最后
    final leftLabel = find.text(firstRow).first;
    final rightLabel = find.text(firstRow).last;
    expect(labels, findsNWidgets(schedule.rows.length * 2));

    final leftBefore = tester.getTopLeft(leftLabel);
    final rightBefore = tester.getTopRight(rightLabel);

    final body = horizontalBody();
    expect(body, findsOneWidget, reason: '表体应是一个横向滚动视图');
    final position = tester.state<ScrollableState>(body).position;
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: '窄屏下 7 天列应撑出横向滚动，否则测不到固定效果',
    );

    await tester.drag(body, const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0), reason: '表体确实滚走了');

    expect(tester.getTopLeft(leftLabel), leftBefore, reason: '左侧行标应固定');
    expect(tester.getTopRight(rightLabel), rightBefore, reason: '右侧行标应固定');
  });

  testWidgets('左右两列行标逐行对齐', (tester) async {
    await pumpGrid(tester);

    for (final row in schedule.rows) {
      final left = find.text(row.label).first;
      final right = find.text(row.label).last;
      expect(
        tester.getTopLeft(right).dy,
        tester.getTopLeft(left).dy,
        reason: '「${row.label}」左右两侧行标的纵向位置应一致',
      );
    }
  });

  testWidgets('一屏放得下时，右侧不再显示行标', (tester) async {
    // 900 宽足够铺下 7 天（58 + 7×98 = 744），节次始终看得见，
    // 右侧那列纯占地方，应该省掉。
    await pumpGrid(tester, size: const Size(900, 900));

    expect(
      find.byType(SlotLabelCell),
      findsNWidgets(schedule.rows.length),
      reason: '放得下时只保留左侧一列',
    );
    expect(
      tester
          .state<ScrollableState>(horizontalBody())
          .position
          .maxScrollExtent,
      0,
      reason: '这个视口本来就不该横向滚动',
    );
  });

  testWidgets('放不下时右侧补一列，且此时确实需要滚动', (tester) async {
    await pumpGrid(tester); // 400 宽

    expect(
      find.byType(SlotLabelCell),
      findsNWidgets(schedule.rows.length * 2),
    );
    expect(
      tester
          .state<ScrollableState>(horizontalBody())
          .position
          .maxScrollExtent,
      greaterThan(0),
    );
  });
}
