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

  /// 手机竖屏宽度（400）：整周必须一屏铺满，不再横向滚动。
  Future<void> pumpGrid(
    WidgetTester tester, {
    Size size = const Size(400, 1200),
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

  testWidgets('手机宽度下一屏铺满：无横向滚动、网格占满视口宽', (tester) async {
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
  });

  testWidgets('表头只渲染本周有课的列，没课的整天不显示', (tester) async {
    await pumpGrid(tester);

    // 有课的列：短星期名 + 日期都在表头。
    for (final day in schedule.days) {
      expect(
        find.text(weekdayShortNames[day - 1]),
        findsOneWidget,
        reason: '周${weekdayLabel(day)}有课，短星期名应在表头',
      );
      final date = DateTime(2026, 10, 26).add(Duration(days: day - 1));
      expect(
        find.text('${date.month}/${date.day}'),
        findsOneWidget,
        reason: '周${weekdayLabel(day)}的日期应在表头',
      );
    }

    // 没课的列整列不出现（2615 数据周六周日无课）。
    for (final day in [6, 7]) {
      if (!schedule.days.contains(day)) {
        expect(
          find.text(weekdayShortNames[day - 1]),
          findsNothing,
          reason: '周${weekdayLabel(day)}没课，不应渲染该列',
        );
      }
    }
  });

  testWidgets('行标：节次号 + 时间段', (tester) async {
    await pumpGrid(tester);

    expect(
      find.byType(SlotLabelCell),
      findsNWidgets(schedule.rows.length),
      reason: '只有行首一列行标',
    );
    // "1-2节" → "1-2"，且带时间段（截取 "08:30" 开头）。
    expect(find.text('1-2'), findsOneWidget);
    final firstStandard = schedule.rows
        .firstWhere((r) => !r.isCustom && r.timeText.isNotEmpty);
    expect(
      find.textContaining(firstStandard.timeText.substring(0, 5)),
      findsWidgets,
      reason: '行标应显示时间段',
    );
  });

  testWidgets('今天列高亮：短星期名与日期都用 onPrimary 前景色', (tester) async {
    await pumpGrid(tester); // todayWeekday = 1（周一）

    expect(schedule.days, contains(1), reason: '周一应有课（2615 数据）');

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

  testWidgets('卡片尺寸统一：宽度全等，高度取最高卡片分给所有行', (tester) async {
    await pumpGrid(tester); // 400 宽

    final cells = tester.renderObjectList<RenderBox>(
      find.byType(CourseCell),
    ).map((box) => box.size).toList();

    expect(cells, isNotEmpty);
    // 宽度：同列等宽（Expanded 平分），全表只出现一种宽度。
    expect(
      cells.map((s) => s.width).toSet().length,
      1,
      reason: '所有课程卡片宽度应一致',
    );
    // 高度：全局等高（最高一行的高度分给所有行）。
    expect(
      cells.map((s) => s.height).toSet().length,
      1,
      reason: '所有课程卡片高度应一致',
    );
  });

  testWidgets('文字放不下时整表撑高：窄视口下行高超过最小高度', (tester) async {
    // 260 宽：有课 5 列时每列 ~40px，长课名换行多行。
    await pumpGrid(tester, size: const Size(260, 1200));

    // 用 renderObject 量实际渲染高度。
    final renderedHeights = tester.renderObjectList<RenderBox>(
      find.byType(CourseCell),
    ).map((box) => box.size.height).toList();

    expect(renderedHeights, isNotEmpty);
    // 最高的卡片把整表撑到超过最小高度，且所有卡片仍等高。
    expect(
      renderedHeights.reduce((a, b) => a > b ? a : b),
      greaterThan(SchedulePalette.cellHeight),
      reason: '窄列下长课名应把整表向下撑高',
    );
    expect(
      renderedHeights.toSet().length,
      1,
      reason: '撑高后所有卡片仍应等高',
    );
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
