import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuki_blog_app/core/asset_timetable_repository.dart';
import 'package:yuki_blog_app/core/network_timetable_repository.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/schedule_page.dart';
import 'package:yuki_blog_app/features/schedule/widgets/course_cell.dart';
import 'package:yuki_blog_app/models/timetable.dart';

void main() {
  final data = TimetableData.fromRawJson(
      File('assets/data/schedule-2615.json').readAsStringSync());
  final realWeek = TimetableResolver(data).currentWeek();

  Widget wrapApp() => MaterialApp(
        // 真实 App 里由 HomeShell 的 Scaffold 提供 Material 祖先
        home: Scaffold(
          body: SchedulePage(repository: InMemoryTimetableRepository(data)),
        ),
      );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  /// 加高测试视口，让首屏断言不必滚动（默认 800x600 装不下整个课表）。
  Future<void> pumpTall(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await TestWidgetsFlutterBinding.instance
        .setSurfaceSize(const Size(420, 2000));
    await tester.pumpAndSettle();
  }

  testWidgets('动态课程表首屏渲染', (tester) async {
    await pumpTall(tester, wrapApp());

    // 头部 / 周条 / 通知 / 图例 / 本周调整
    expect(find.text('软件2615 · 动态课程表'), findsOneWidget);
    expect(find.text('第 $realWeek 周'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('有课'), findsWidgets); // 图例
    expect(find.text('本周调整'), findsOneWidget);

    // 今天列表头（按真实系统日期动态算）
    final today = DateTime.now();
    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    expect(
        find.text('${weekdays[today.weekday]} ${today.month}/${today.day}'),
        findsOneWidget);

    // 已在本周时不显示「回到本周」
    expect(find.text('回到本周'), findsNothing);

    // 有课程格子
    expect(find.byType(CourseCell), findsWidgets);

    // 数据更新历在页面最底部（超出视口，懒构建）：滚动到底再断言。
    // 页面里有多个 Scrollable（网格横向滚动），须显式指定纵向的列表。
    final verticalList = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    ).first;
    await tester.scrollUntilVisible(
      find.text('数据更新历'),
      600,
      scrollable: verticalList,
      maxScrolls: 20,
    );
    expect(find.text('数据更新历'), findsOneWidget);
    expect(find.textContaining('最近更新于'), findsWidgets);
    expect(find.textContaining('团支书'), findsWidgets); // 更新历 + 通知区
  });

  testWidgets('网络同步失败时置顶展示离线数据提醒', (tester) async {
    final staleRepo = SyncTimetableRepository(
      client: MockClient((req) async => http.Response('offline', 503)),
    );
    await pumpTall(
      tester,
      MaterialApp(
        home: Scaffold(
          body: SchedulePage(repository: staleRepo),
        ),
      ),
    );

    expect(find.textContaining('网络同步失败'), findsOneWidget);
    expect(find.textContaining('可能不是最新'), findsOneWidget);
    // 正常展示课表内容（离线兜底生效）
    expect(find.text('软件2615 · 动态课程表'), findsOneWidget);
  });

  testWidgets('网络同步成功时不展示离线提醒', (tester) async {
    final okRepo = SyncTimetableRepository(
      client: MockClient((req) async => http.Response.bytes(
            utf8.encode(
                File('assets/data/schedule-2615.json').readAsStringSync()),
            200,
          )),
    );
    await pumpTall(
      tester,
      MaterialApp(
        home: Scaffold(
          body: SchedulePage(repository: okRepo),
        ),
      ),
    );

    expect(find.textContaining('网络同步失败'), findsNothing);
  });

  testWidgets('点击格子展开详情，再点收起', (tester) async {
    await pumpTall(tester, wrapApp());

    // 第一个格子 = 周一 1-2 习概
    final firstCell = find.byType(CourseCell).first;
    await tester.ensureVisible(firstCell);
    await tester.tap(firstCell);
    await tester.pumpAndSettle();

    expect(find.textContaining('习近平新时代'), findsWidgets); // 详情面板标题
    expect(find.text('教师'), findsOneWidget);
    expect(find.text('周次'), findsOneWidget);

    // 再点同一格收起
    await tester.tap(firstCell);
    await tester.pumpAndSettle();
    expect(find.text('教师'), findsNothing);
  });

  testWidgets('下一周后出现「回到本周」，且可跳回', (tester) async {
    await pumpTall(tester, wrapApp());

    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();
    expect(find.text('第 ${realWeek + 1} 周'), findsOneWidget);
    expect(find.text('回到本周'), findsOneWidget);

    await tester.tap(find.text('回到本周'));
    await tester.pumpAndSettle();
    expect(find.text('第 $realWeek 周'), findsOneWidget);
    expect(find.text('回到本周'), findsNothing);
  });

  testWidgets('周次选择弹层：跳到第 5 周显示无课横幅', (tester) async {
    await pumpTall(tester, wrapApp());

    await tester.tap(find.text('第 $realWeek 周'));
    await tester.pumpAndSettle();
    expect(find.text('选择周次'), findsOneWidget);
    expect(find.text('第 19 周'), findsOneWidget);

    await tester.tap(find.text('第 5 周'));
    await tester.pumpAndSettle();
    expect(find.text('第 5 周'), findsOneWidget);
    expect(find.textContaining('第 5 周无课安排'), findsOneWidget);
  });
}
