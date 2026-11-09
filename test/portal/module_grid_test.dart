import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/features/campus/portal/widgets/module_grid.dart';
import 'package:yuki_blog_app/features/campus/shared/module_launcher.dart';

void main() {
  testWidgets('六个模块全部渲染', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleGrid(counts: const {}, onTap: (_) {}),
        ),
      ),
    );

    for (final module in CampusModule.values) {
      expect(find.text(module.label), findsOneWidget, reason: module.name);
    }
  });

  testWidgets('有待处理的模块显示角标，没有的不显示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleGrid(
            counts: const {'lostFound': 3, 'forms': 12},
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('点击卡片回调对应模块', (tester) async {
    CampusModule? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleGrid(
            counts: const {},
            onTap: (module) => tapped = module,
          ),
        ),
      ),
    );

    await tester.tap(find.text('二手闲置'));
    await tester.pump();

    expect(tapped, CampusModule.market);
  });
}
