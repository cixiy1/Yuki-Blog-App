import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuki_blog_app/features/todo/todo_model.dart';
import 'package:yuki_blog_app/features/todo/todo_page.dart';
import 'package:yuki_blog_app/features/todo/todo_storage.dart';

void main() {
  late MemoryTodoStorage storage;

  Future<void> pumpTodo(WidgetTester tester) async {
    storage = MemoryTodoStorage();
    await tester.pumpWidget(
      MaterialApp(home: TodoPage(storage: storage)),
    );
    await tester.pumpAndSettle();
  }

  /// 通过右下角 FAB 打开对话框，填标题后确认添加。
  Future<void> addTodo(WidgetTester tester, String title) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, title);
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();
  }

  testWidgets('初始为空时显示空状态引导', (tester) async {
    await pumpTodo(tester);
    expect(find.text('点右下角 + 添加你的第一条待办'), findsOneWidget);
    expect(find.text('暂无待办'), findsOneWidget);
  });

  testWidgets('新建一条待办会出现在列表中', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '收齐教材费');
    expect(find.text('收齐教材费'), findsOneWidget);
    // 统计：1 项待完成
    expect(find.text('1 项待完成 · 共 1 项'), findsOneWidget);
  });

  testWidgets('勾选完成后，按筛选在「已完成」显示、在「进行中」隐藏',
      (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '交入党申请书');

    // 默认「全部」可见
    expect(find.text('交入党申请书'), findsOneWidget);

    // 勾选完成
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // 切到「进行中」：应隐藏
    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.text('交入党申请书'), findsNothing);

    // 切到「已完成」：应显示
    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    expect(find.text('交入党申请书'), findsOneWidget);
  });

  testWidgets('删除按钮移除对应待办', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '待删除项');
    expect(find.text('待删除项'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('待删除项'), findsNothing);
  });

  testWidgets('点击待办可编辑标题', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '原标题');

    await tester.tap(find.text('原标题'));
    await tester.pumpAndSettle();

    // 对话框预填原标题，清空后改新标题
    await tester.enterText(find.byType(TextFormField).first, '改后标题');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('改后标题'), findsOneWidget);
    expect(find.text('原标题'), findsNothing);
  });

  testWidgets('存储可序列化往返', (tester) async {
    storage = MemoryTodoStorage();
    final original = TodoItem(
      id: 'x1',
      title: '序列化测试',
      note: '备注',
      category: TodoCategory.party,
      dueDate: DateTime(2026, 11, 1),
    );
    await storage.save([original]);
    final loaded = await storage.load();
    expect(loaded.length, 1);
    expect(loaded.first.title, '序列化测试');
    expect(loaded.first.category, TodoCategory.party);
    expect(loaded.first.dueDate, DateTime(2026, 11, 1));
    expect(loaded.first.toJson()['category'], 'party');
  });
}
