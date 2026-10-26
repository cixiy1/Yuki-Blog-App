import 'package:flutter_test/flutter_test.dart';

import 'package:yuki_blog_app/core/todo_repository.dart';
import 'package:yuki_blog_app/features/todo/todo_model.dart';

/// 取自博客《待办清单》文章结构的精简样例（含分组 / 子标题 / 备注 /
/// 嵌套子列表 / 截止状态），用于验证解析器能正确还原待办项。
const _sampleHtml = '''
<html><body>
<div class="todo-root"><div class="todo-card">
  <div class="todo-group">
    <h3 class="todo-group-title">雪穗的待办</h3>
    <ul class="todo-list">
      <li><label class="todo-item"><input type="checkbox" class="todo-check" data-todo-id="intro"><span class="todo-box"></span><span class="todo-text">写一篇个人介绍</span></label></li>
    </ul>
    <h4 class="todo-subhead">第二批入党申请谈话：10.15 周四 15:00（暂定）</h4>
    <p class="todo-note">谈话可能涉及党的基本知识</p>
    <ul class="todo-list todo-sublist">
      <li><label class="todo-item"><input type="checkbox" class="todo-check" data-todo-id="party-talk-prep"><span class="todo-box"></span><span class="todo-text">准备谈话内容<span class="todo-status">10.15 周四 15:00 暂定</span></span></label></li>
    </ul>
  </div>
  <div class="todo-group">
    <h3 class="todo-group-title">软件2615同学待办</h3>
    <h4 class="todo-subhead">英语作业</h4>
    <p class="todo-note">第7周英语作业</p>
    <ul class="todo-list todo-sublist">
      <li><label class="todo-item"><input type="checkbox" class="todo-check" data-todo-id="eng-w7-unit1"><span class="todo-box"></span><span class="todo-text">完成第一单元的线上课任务点<span class="todo-status">第8周周日 10.25 23:00 关闭</span></span></label></li>
    </ul>
  </div>
</div></div>
</body></html>
''';

void main() {
  test('解析出全部待办项', () {
    final items = parseTodoHtml(_sampleHtml);
    expect(items.length, 3);
  });

  test('分组映射到分类', () {
    final items = parseTodoHtml(_sampleHtml);
    final intro = items.firstWhere((e) => e.id == 'intro');
    expect(intro.category, TodoCategory.personal);

    final eng = items.firstWhere((e) => e.id == 'eng-w7-unit1');
    expect(eng.category, TodoCategory.classAffairs);
  });

  test('标题去掉状态文案、保留纯净文本', () {
    final items = parseTodoHtml(_sampleHtml);
    final eng = items.firstWhere((e) => e.id == 'eng-w7-unit1');
    expect(eng.title, '完成第一单元的线上课任务点');
    expect(eng.dueLabel, contains('10.25'));
  });

  test('截止文案解析为日期 + 备注带子标题上下文', () {
    final items = parseTodoHtml(_sampleHtml);
    final party = items.firstWhere((e) => e.id == 'party-talk-prep');
    expect(party.dueLabel, contains('10.15'));
    expect(party.dueDate, DateTime(DateTime.now().year, 10, 15));
    expect(party.note, contains('谈话可能涉及'));
    expect(party.note, contains('第二批入党申请谈话'));

    final eng = items.firstWhere((e) => e.id == 'eng-w7-unit1');
    expect(eng.dueDate, DateTime(DateTime.now().year, 10, 25));
    expect(eng.note, contains('英语作业'));
    expect(eng.note, contains('第7周英语作业'));
  });

  test('无 .todo-root 时返回空', () {
    expect(parseTodoHtml('<div>nothing</div>'), isEmpty);
  });
}
