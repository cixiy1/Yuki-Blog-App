import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/course_cell.dart';
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

  /// 手机竖屏宽度（400）：整周 7 列必须一屏铺满，不再横向滚动。
  Future<void> pumpGrid(
    WidgetTester tester, {
    Size size = const Size(400, 900),
    void Function(ResolvedEntry)? onSelect,
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
              onSelectEntry: onSelect ?? (_) {},
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

  testWidgets('手机宽度下一屏铺满整周：无横向滚动、7 列等宽占满视口', (tester) async {
    await pumpGrid(tester); // 400 宽

    expect(
      horizontalBody(),
      findsNothing,
      reason: '整周布局不允许横向滚动',
    );

    // 网格宽度 = 视口宽度（列宽 Expanded 平分，不留缝）。
    expect(
      tester.getSize(find.byType(TimetableGrid)).width,
      400,
    );

    // 表头 7 列：短星期名 一~日 + 各自日期。
    for (var day = 1; day <= 7; day++) {
      expect(
        find.text(weekdayShortNames[day - 1]),
        findsOneWidget,
        reason: '周${weekdayLabel(day)}列的短星期名应在表头',
      );
      final date = DateTime(2026, 10, 26).add(Duration(days: day - 1));
      expect(find.text('${date.month}/${date.day}'), findsOneWidget);
    }
  });

  testWidgets('行标紧凑化：每行只留行首一个短节次号', (tester) async {
    await pumpGrid(tester);

    expect(
      find.byType(SlotLabelCell),
      findsNWidgets(schedule.rows.length),
      reason: '只有行首一列行标',
    );
    // "1-2节" → "1-2"：剥掉「节」字。
    expect(find.text('1-2'), findsOneWidget);
  });

  testWidgets('今天列高亮：短星期名与日期都用 onPrimary 前景色', (tester) async {
    await pumpGrid(tester); // todayWeekday = 1（周一）

    final onPrimary = AppTheme.light.colorScheme.onPrimary;
    for (final label in ['一', '10/26']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.color, onPrimary,
          reason: '今天列（周一）的 "$label" 应高亮');
    }
    // 非今天的列不高亮。
    final tuesday = tester.widget<Text>(find.text('二'));
    expect(tuesday.style?.color, isNot(onPrimary));
  });

  testWidgets('点格子触发选中回调', (tester) async {
    ResolvedEntry? picked;
    await pumpGrid(tester, onSelect: (e) => picked = e);

    final cell = find.byType(CourseCell).first;
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    final widget = tester.widget<CourseCell>(cell);
    expect(picked!.key, widget.entry.key);
  });
}
