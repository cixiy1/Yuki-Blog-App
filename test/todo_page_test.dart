import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuki_blog_app/core/todo_repository.dart';
import 'package:yuki_blog_app/features/todo/todo_model.dart';
import 'package:yuki_blog_app/features/todo/todo_page.dart';
import 'package:yuki_blog_app/features/todo/todo_storage.dart';

/// 测试用远端源：同步返回固定列表，或按要求抛异常（模拟离线）。
class FakeRemote implements TodoRemoteSource {
  FakeRemote(this.items, {this.throws = false});
  final List<RemoteTodo> items;
  final bool throws;

  @override
  Future<List<RemoteTodo>> fetch() async {
    if (throws) throw const TodoNetworkException('x', ['x']);
    return items;
  }
}

RemoteTodo remote(String id, String title, TodoCategory c, {String? group}) =>
    RemoteTodo(id: id, title: title, category: c, group: group);

void main() {
  late MemoryTodoStorage storage;

  Future<void> pumpTodo(
    WidgetTester tester, {
    TodoRemoteSource remote = const _EmptyRemote(),
  }) async {
    storage = MemoryTodoStorage();
    await tester.pumpWidget(
      MaterialApp(home: TodoPage(storage: storage, remote: remote)),
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

  testWidgets('初始为空时显示空状态引导', (tester) async {
    await pumpTodo(tester);
    expect(find.text('点右下角 + 添加你的第一条待办'), findsOneWidget);
    expect(find.text('暂无待办'), findsOneWidget);
  });

  testWidgets('新建一条待办会出现在列表中', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '收齐教材费');
    expect(find.text('收齐教材费'), findsOneWidget);
    expect(find.text('1 项待完成 · 共 1 项'), findsOneWidget);
  });

  testWidgets('勾选完成后，按筛选在「已完成」显示、在「进行中」隐藏',
      (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '交入党申请书');

    expect(find.text('交入党申请书'), findsOneWidget);

    await tester.tap(find.byType(TodoCheckCircle));
    await tester.pumpAndSettle();

    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.text('交入党申请书'), findsNothing);

    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    expect(find.text('交入党申请书'), findsOneWidget);
  });

  testWidgets('删除按钮移除对应待办', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '待删除项');
    expect(find.text('待删除项'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('待删除项'), findsNothing);
  });

  testWidgets('点击待办可编辑标题', (tester) async {
    await pumpTodo(tester);
    await addTodo(tester, '原标题');

    await tester.tap(find.text('原标题'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '改后标题');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('改后标题'), findsOneWidget);
    expect(find.text('原标题'), findsNothing);
  });

  testWidgets('自动拉取：远端文章里的待办会被合并且标注云端',
      (tester) async {
    final r = FakeRemote([
      remote('r1', '写个人介绍', TodoCategory.personal),
      remote('r2', '英语第7周作业', TodoCategory.classAffairs),
    ]);
    await pumpTodo(tester, remote: r);

    expect(find.text('写个人介绍'), findsOneWidget);
    expect(find.text('英语第7周作业'), findsOneWidget);
    // 远端项带云端图标
    expect(find.byIcon(Icons.cloud_outlined), findsWidgets);
    // 同步状态文案
    expect(find.text('已同步'), findsOneWidget);
  });

  testWidgets('离线时回退本地数据，不丢本地改动', (tester) async {
    await pumpTodo(tester, remote: FakeRemote([], throws: true));
    await addTodo(tester, '本地草稿');
    // 离线提示
    expect(find.text('离线，显示本地'), findsOneWidget);
    expect(find.text('本地草稿'), findsOneWidget);
  });

  testWidgets('本地自建项与远端并存，远端删除（墓碑）后不再复活',
      (tester) async {
    // 先注入含一个远端项的存储，再让远端继续返回它，删除后应不回来。
    final store = TodoStore(items: [
      TodoItem(
        id: 'remote-x',
        remoteId: 'x',
        title: '待复活项',
        category: TodoCategory.personal,
        source: TodoSource.remote,
      ),
    ]);
    storage = MemoryTodoStorage(store);
    final r = FakeRemote([remote('x', '待复活项', TodoCategory.personal)]);
    await tester.pumpWidget(
      MaterialApp(home: TodoPage(storage: storage, remote: r)),
    );
    await tester.pumpAndSettle();
    expect(find.text('待复活项'), findsOneWidget);

    // 删除该远端项（记入墓碑）
    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('待复活项'), findsNothing);

    // 再次同步，远端仍在返回 x，但被墓碑挡住，不应复活
    await tester.fling(
      find.byType(ListView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('待复活项'), findsNothing);
  });

  testWidgets('存储可序列化往返（含墓碑）', (tester) async {
    storage = MemoryTodoStorage();
    final original = TodoItem(
      id: 'x1',
      title: '序列化测试',
      note: '备注',
      category: TodoCategory.party,
      dueDate: DateTime(2026, 11, 1),
      source: TodoSource.remote,
      remoteId: 'abc',
    );
    await storage.save(TodoStore(
      items: [original],
      deletedRemoteIds: {'abc'},
    ));
    final loaded = await storage.load();
    expect(loaded.items.length, 1);
    expect(loaded.items.first.title, '序列化测试');
    expect(loaded.items.first.category, TodoCategory.party);
    expect(loaded.items.first.dueDate, DateTime(2026, 11, 1));
    expect(loaded.items.first.remoteId, 'abc');
    expect(loaded.deletedRemoteIds, contains('abc'));
    expect(loaded.items.first.toJson()['category'], 'party');
  });

  testWidgets('按人/组(group)顶层分块、组内按科目(subject)子分区', (tester) async {
    final r = FakeRemote([
      RemoteTodo(
        id: 'a',
        title: '英语课文朗读',
        category: TodoCategory.classAffairs,
        group: '软件2615同学待办',
        subject: '英语作业',
      ),
      RemoteTodo(
        id: 'b',
        title: 'Java 实验报告',
        category: TodoCategory.classAffairs,
        group: '软件2615同学待办',
        subject: 'Java程序设计',
      ),
      RemoteTodo(
        id: 'c',
        title: '写个人介绍',
        category: TodoCategory.personal,
        group: '雪穗的待办',
      ),
    ]);
    await pumpTodo(tester, remote: r);
    // 顶层按人/组分块
    expect(find.text('软件2615同学待办'), findsOneWidget);
    expect(find.text('雪穗的待办'), findsOneWidget);
    // 组内按科目子分区
    expect(find.text('英语作业'), findsOneWidget);
    expect(find.text('Java程序设计'), findsOneWidget);
    // 条目标题照常显示
    expect(find.text('英语课文朗读'), findsOneWidget);
    expect(find.text('写个人介绍'), findsOneWidget);
  });

  test('TodoItem 序列化往返保留 startDate/subject/group', () {
    final item = TodoItem(
      id: 'a1',
      title: '社团招新',
      subject: '宣传物料',
      group: '社团活动',
      startDate: DateTime(2026, 10, 28),
      dueDate: DateTime(2026, 11, 1),
    );
    final back = TodoItem.fromJson(item.toJson());
    expect(back.startDate, DateTime(2026, 10, 28));
    expect(back.dueDate, DateTime(2026, 11, 1));
    expect(back.subject, '宣传物料');
    expect(back.group, '社团活动');
    // 自定义分类名作为顶层分组标签
    expect(back.groupLabel, '社团活动');
  });

  testWidgets('新建待办可设定细分分类与自定义分类', (tester) async {
    await pumpTodo(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // 标题 / 备注 / 细分分类 三个输入框
    await tester.enterText(find.byType(TextFormField).at(0), '做竞赛 PPT');
    await tester.enterText(find.byType(TextFormField).at(2), '竞赛准备');
    // 选「自定义」分类并输入名称
    await tester.tap(find.text('自定义'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(3), '学科竞赛');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    // 自定义分类名成为顶层组名，细分分类成为子区块标题
    expect(find.text('学科竞赛'), findsOneWidget);
    expect(find.text('竞赛准备'), findsOneWidget);
    expect(find.text('做竞赛 PPT'), findsOneWidget);
  });

  testWidgets('编辑待办可修改细分分类并保留分组', (tester) async {
    final r = FakeRemote([
      RemoteTodo(
        id: 'e1',
        title: '英语课文朗读',
        category: TodoCategory.classAffairs,
        group: '软件2615同学待办',
        subject: '英语作业',
      ),
    ]);
    await pumpTodo(tester, remote: r);

    // 打开编辑对话框，细分分类输入框已预填原科目
    await tester.tap(find.text('英语课文朗读'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField).at(2), findsOneWidget);

    // 只改标题保存；分组与细分分类不应丢
    await tester.enterText(find.byType(TextFormField).at(0), '英语课文跟读');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('英语课文跟读'), findsOneWidget);
    expect(find.text('软件2615同学待办'), findsOneWidget);
    expect(find.text('英语作业'), findsOneWidget);
  });
}

/// 默认空远端，避免测试中真的去联网。
class _EmptyRemote implements TodoRemoteSource {
  const _EmptyRemote();
  @override
  Future<List<RemoteTodo>> fetch() async => const [];
}
