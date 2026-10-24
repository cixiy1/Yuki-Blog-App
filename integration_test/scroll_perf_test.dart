import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yuki_blog_app/core/asset_timetable_repository.dart';
import 'package:yuki_blog_app/features/schedule/schedule_page.dart';
import 'package:yuki_blog_app/models/timetable.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

/// 课表页滚动性能基准（只跑 profile，debug 数据没有参考意义）：
///
/// ```sh
/// flutter test integration_test/scroll_perf_test.dart -d macos --profile
/// ```
///
/// 输出 `average_frame_build_time_millis` / `average_frame_rasterizer_time_millis`
/// / `worst_frame_rasterizer_time_millis` 等指标。判断标准很简单：
/// rasterizer 平均超过 16.7ms 就必然掉帧，罪魁一般是标题栏那层
/// `BackdropFilter`（σ=20、每帧对滚动内容重新取样 + 高斯模糊）。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('课表页来回滚动 6 个来回', (tester) async {
    final raw = await rootBundle.loadString('assets/data/schedule-2615.json');
    final data = TimetableData.fromRawJson(raw);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ImmersiveScaffold(
          title: '动态课程表',
          body: SchedulePage(repository: InMemoryTimetableRepository(data)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ListView);
    expect(list, findsOneWidget);

    await binding.watchPerformance(() async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -420), 1400);
        await tester.pumpAndSettle();
        await tester.fling(list, const Offset(0, 420), 1400);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'scroll');
  });
}
