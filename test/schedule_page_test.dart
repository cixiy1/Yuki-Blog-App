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
import 'package:yuki_blog_app/features/schedule/widgets/course_detail_panel.dart';
import 'package:yuki_blog_app/features/schedule/widgets/timetable_grid.dart';
import 'package:yuki_blog_app/models/timetable.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

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
    // setSurfaceSize 是 binding 级的覆盖，优先级高于 tester.view.physicalSize，
    // 不复位会漏给后面的用例：视口还是 2000 高，页面撑不满就滚不动，
    // jumpTo 被夹到 0，沉浸标题栏那类「滚过阈值才出玻璃」的断言必挂。
    addTearDown(() => TestWidgetsFlutterBinding.instance.setSurfaceSize(null));
    await tester.pumpAndSettle();
  }

  testWidgets('动态课程表首屏渲染', (tester) async {
    await pumpTall(tester, wrapApp());

    // 头部 / 周条 / 通知 / 本周调整 / 图例
    expect(find.text('软件2615'), findsOneWidget);
    expect(find.text('第 $realWeek 周'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('有课'), findsWidgets); // 图例
    expect(find.text('本周调整'), findsOneWidget);

    // 面板顺序：通知在上、本周调整在下。
    expect(
      tester.getTopLeft(find.text('通知')).dy,
      lessThan(tester.getTopLeft(find.text('本周调整')).dy),
      reason: '「通知」应在「本周调整」上方',
    );

    // 表头：只渲染**有课的星期列**（resolver 的 days =「数据里出现过的
    // 星期」∪「本周有条目的星期」，2615 班没有周六日的课），所以断言必须
    // 从 days 反推，不能假定「今天一定有列」——2026-10-17 周六踩过：
    // 原来写死断「今天列存在」，周五能过、一到周末必挂。
    final resolver = TimetableResolver(data);
    final viewSchedule = resolver.resolve(realWeek);
    final monday = resolver.mondayOf(realWeek);
    expect(viewSchedule.days, isNotEmpty);
    for (final day in viewSchedule.days) {
      final date = monday.add(Duration(days: day - 1));
      expect(
        find.text('${weekdayLabel(day)} ${date.month}/${date.day}'),
        findsOneWidget,
        reason: '第 $day 列（${date.month}/${date.day}）应在表头',
      );
    }

    // 今天落在本周、且本周确实有这一列时，表头才该出现今天的标签。
    final today = DateTime.now();
    expect(
      find.text('${weekdayLabel(today.weekday)} ${today.month}/${today.day}'),
      viewSchedule.days.contains(today.weekday) ? findsOneWidget : findsNothing,
    );

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
    // 更新历默认折叠（只建最新 4 条），更早的记录要先展开才看得到。
    // 折叠是刻意的：面板原来内嵌滚动框，会独占鼠标滚轮，页面滑到这里就卡住。
    final expandLabel = find.textContaining('展开全部');
    expect(expandLabel, findsOneWidget);
    await tester.ensureVisible(expandLabel);
    await tester.pumpAndSettle();
    await tester.tap(expandLabel);
    await tester.pumpAndSettle();
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
    expect(find.text('软件2615'), findsOneWidget);
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

    // 目标格 = 周一 1-2 习概（c01）。第 7 周起多了一行「体检」顶行（周日列），
    // DOM 里第一个 CourseCell 不再是习概，必须按 entry.key 定位。
    final firstCell = find.byWidgetPredicate(
        (w) => w is CourseCell && w.entry.key == 'c01');
    await tester.ensureVisible(firstCell);
    await tester.tap(firstCell);
    await tester.pumpAndSettle();

    expect(find.textContaining('习近平新时代'), findsWidgets); // 详情面板标题
    expect(find.text('教师'), findsOneWidget);
    expect(find.text('周次'), findsOneWidget);

    // 详情紧贴网格，排在通知之上（点哪格就在它下面看，不用跨过通知区）
    expect(
      tester.getTopLeft(find.byType(CourseDetailPanel)).dy,
      lessThan(tester.getTopLeft(find.text('通知')).dy),
      reason: '课程详情应在「通知」上方',
    );

    // 再点同一格收起
    await tester.tap(firstCell);
    await tester.pumpAndSettle();
    expect(find.text('教师'), findsNothing);
  });

  testWidgets('课程详情的调整说明走高亮：只有词表着色，不铺句子底纹', (tester) async {
    await pumpTall(tester, wrapApp());

    // 目标格 = 周一 1-2 习概（c01，本周带「换地点」长期说明）
    final firstCell = find.byWidgetPredicate(
        (w) => w is CourseCell && w.entry.key == 'c01');
    await tester.ensureVisible(firstCell);
    await tester.tap(firstCell);
    await tester.pumpAndSettle();

    final panel = find.byType(CourseDetailPanel);
    expect(panel, findsOneWidget);

    // visitChildren 自身会递归（并在 text 非空时先访问自身），回调里不要再递归
    final spans = <TextSpan>[];
    bool visit(InlineSpan s) {
      if (s is TextSpan) spans.add(s);
      return true;
    }

    for (final rt in tester.widgetList<RichText>(
      find.descendant(of: panel, matching: find.byType(RichText)),
    )) {
      rt.text.visitChildren(visit);
    }

    expect(spans, isNotEmpty);
    // 长说明被词表着色：出现带同色划线的高亮词
    expect(
      spans.any((s) => s.style?.decoration != null && s.style?.color != null),
      isTrue,
      reason: '详情里的长说明应走高亮（词表着色）',
    );
    // 只着色：整块详情不铺任何句子底纹、不按档位加粗
    expect(spans.every((s) => s.style?.background == null), isTrue);
    expect(
      spans.every((s) => s.style?.fontWeight != FontWeight.w600),
      isTrue,
    );
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
  testWidgets('套沉浸标题栏后：首屏避开标题栏，滚动时内容钻到它下面', (tester) async {
    // 回归：Scaffold 挂了 appBar 会把 body 的 MediaQuery.padding.top 清成 0，
    // 而 ListView 又只在 padding 为 null 时自动套用 MediaQuery 留白 ——
    // 课表页是显式 padding，所以必须自己补上标题栏高度，否则首屏内容会被压住。
    //
    // 视口显式钉死并复位：前面的用例用 pumpTall 把测试面拉到 420x2000，
    // 那份尺寸会残留到后续用例，页面撑不满视口就滚不动，jumpTo 直接失效。
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ImmersiveScaffold(
        title: '动态课程表',
        body: SchedulePage(repository: InMemoryTimetableRepository(data)),
      ),
    ));
    await tester.pumpAndSettle();

    final header = find.text('软件2615');
    expect(tester.getTopLeft(header).dy, greaterThanOrEqualTo(kToolbarHeight));

    // 纵向列表 = 页面自己那个（横向课表网格也是 Scrollable，按轴向挑）
    final verticalList = find
        .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .first;
    final position = tester.state<ScrollableState>(verticalList).position;
    expect(position.maxScrollExtent, greaterThan(60),
        reason: '页面要能滚动，否则这个用例测不到折叠进度');

    // 往上一推，班级名就钻进标题栏底下（毛玻璃这才有东西可糊）。
    // 只滚 60px：标题行仍半露在视口里不会被回收，又已经进入标题栏那条带；
    // 用 jumpTo 而不是 drag —— drag 抬手的惯性会把首屏几行直接甩出缓存区。
    position.jumpTo(60);
    await tester.pump();
    expect(tester.getTopLeft(header).dy, lessThan(kToolbarHeight));

    await tester.pumpAndSettle();
    // 整条统一模糊：只有一层（分带写法已废）
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
