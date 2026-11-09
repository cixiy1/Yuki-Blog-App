import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuki_blog_app/core/todo_repository.dart';
import 'package:yuki_blog_app/features/todo/todo_model.dart';
import 'package:yuki_blog_app/features/todo/todo_page.dart';
import 'package:yuki_blog_app/features/todo/todo_storage.dart';

/// 空远端，避免测试真心联网。
class _EmptyRemote implements TodoRemoteSource {
  const _EmptyRemote();
  @override
  Future<List<RemoteTodo>> fetch() async => const [];
}

class _FakeRemote implements TodoRemoteSource {
  _FakeRemote(this.items);
  final List<RemoteTodo> items;
  @override
  Future<List<RemoteTodo>> fetch() async => items;
}

void main() {
  late MemoryTodoStorage storage;

  /// 默认套一层 Scaffold：真实环境里页面由 ImmersiveScaffold 提供 Scaffold，
  /// 删除后要弹 SnackBar。
  Future<void> pumpTodo(
    WidgetTester tester, {
    TodoRemoteSource remote = const _EmptyRemote(),
    TodoStore? initial,
    bool withScaffold = true,
  }) async {
    storage = MemoryTodoStorage(initial);
    final page = TodoPage(storage: storage, remote: remote);
    await tester.pumpWidget(
      MaterialApp(home: withScaffold ? Scaffold(body: page) : page),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addTodo(WidgetTester tester, String title) async {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, title);
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();
  }

  Future<void> openTrash(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.restore_from_trash_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
  }

  testWidgets('删除是软删除：移出主列表、计入回收站、不影响剩余统计',
      (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '甲项');
    await addTodo(tester, '乙项');
    expect(find.text('2 项待完成 · 共 2 项'), findsOneWidget);

    // 删掉第一条（列表里最后添加的「乙项」在最上面，这里按标题定位删除按钮太脆，
    // 直接删「乙项」那张卡片内的图标）
    final card = find.ancestor(
      of: find.text('乙项'),
      matching: find.byType(Dismissible),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byIcon(Icons.delete_outline)),
    );
    await tester.pumpAndSettle();

    expect(find.text('乙项'), findsNothing);
    expect(find.text('1 项待完成 · 共 1 项'), findsOneWidget);
    // 数据仍在存储里，只是打了删除时间
    final saved = await storage.load();
    expect(saved.items.length, 2);
    expect(saved.items.where((e) => e.trashed).length, 1);
  });

  testWidgets('回收站可以还原，还原后回到原分组', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '待还原项');

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('待还原项'), findsNothing);

    await openTrash(tester);
    expect(find.text('回收站'), findsOneWidget);
    expect(find.text('待还原项'), findsWidgets);
    expect(find.text('还原'), findsOneWidget);

    await tester.tap(find.text('还原'));
    await tester.pumpAndSettle();
    expect(find.text('回收站是空的'), findsOneWidget);

    await back(tester);
    expect(find.text('待还原项'), findsOneWidget);
  });

  testWidgets('彻底删除后，远端再返回同一条也不会复活', (tester) async {
    final remote = _FakeRemote([
      RemoteTodo(id: 'x', title: '远端待删项', category: TodoCategory.personal),
    ]);
    await pumpTodo(tester, remote: remote);
    expect(find.text('远端待删项'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();

    await openTrash(tester);
    await tester.tap(find.text('彻底删除'));
    await tester.pumpAndSettle();
    expect(find.text('回收站是空的'), findsOneWidget);

    // 回主列表下拉同步：远端仍在返回 x，但已记墓碑
    await back(tester);
    await tester.fling(find.byType(ListView).first, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(find.text('远端待删项'), findsNothing);
    final saved = await storage.load();
    expect(saved.deletedRemoteIds, contains('x'));
  });

  testWidgets('清空回收站会清掉全部条目', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '甲项');
    await addTodo(tester, '乙项');

    for (final t in ['甲项', '乙项']) {
      final card = find.ancestor(
        of: find.text(t),
        matching: find.byType(Dismissible),
      );
      await tester.tap(
        find.descendant(of: card, matching: find.byIcon(Icons.delete_outline)),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('暂无待办'), findsOneWidget);

    await openTrash(tester);
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('彻底删除 2 条待办'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();

    expect(find.text('回收站是空的'), findsOneWidget);
    final saved = await storage.load();
    expect(saved.items, isEmpty);
  });

  testWidgets('删除后可从 SnackBar 撤销', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '手滑删掉的');

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    // 只 pump 一帧时 SnackBar 还在滑入过程，点不到按钮
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('已移入回收站'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(find.text('手滑删掉的'), findsOneWidget);

    // 让 SnackBar 的自动消失计时器走完，避免残留 pending timer
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('窄屏（360 宽）回收站行内按钮不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpTodo(tester);
    await addTodo(tester, '一个特别特别长的待办标题用来把这一行撑满看看会不会爆');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    await openTrash(tester);

    expect(find.text('还原'), findsOneWidget);
    expect(find.text('彻底删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('TodoItem 序列化保留 deletedAt', () {
    final item = TodoItem(
      id: 't1',
      title: '回收站条目',
      deletedAt: DateTime(2026, 11, 9, 12, 30),
    );
    final back = TodoItem.fromJson(item.toJson());
    expect(back.deletedAt, DateTime(2026, 11, 9, 12, 30));
    expect(back.trashed, isTrue);
    // 还原清掉删除时间
    expect(back.copyWith(clearDeletedAt: true).trashed, isFalse);
  });

  test('回收站删除时间文案', () {
    final now = DateTime.now();
    expect(formatTrashAge(now), '刚刚删除');
    expect(formatTrashAge(now.subtract(const Duration(minutes: 5))), '5 分钟前删除');
    expect(formatTrashAge(now.subtract(const Duration(hours: 2))), '2 小时前删除');
    expect(formatTrashAge(now.subtract(const Duration(days: 3))), '3 天前删除');
  });
}
