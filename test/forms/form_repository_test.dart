import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/models/campus/campus_form.dart';

import '../support/campus_fixtures.dart';

/// 两张题目的最小表，够测提交与锁定。
List<FormFieldSpec> _fields() => [
      const FormFieldSpec(
        id: 'q1',
        type: FormFieldType.singleLine,
        label: '姓名',
        required: true,
        maxLength: 20,
      ),
      const FormFieldSpec(
        id: 'q2',
        type: FormFieldType.singleChoice,
        label: '领取方式',
        required: true,
        options: [
          FormOption(id: 'a', label: '自提'),
          FormOption(id: 'b', label: '送宿舍'),
        ],
      ),
    ];

void main() {
  test('进行中的表里不出现已关闭的表', () async {
    final services = await testServices();

    final open = await services.forms.list();
    final titles = open.items.map((f) => f.title).toList();
    expect(titles, contains('教材选购登记'));
    expect(titles, isNot(contains('入党申请书材料收集')));
    expect(open.items.first.fields.length, greaterThan(0));
  });

  test('待我填只给还没提交的表', () async {
    final services = await testServices();

    final todo = await services.forms.list(filter: 'todo');
    expect(todo.items.map((f) => f.title), contains('教材选购登记'));

    // 张小明 填完后就不在待填列表里了。
    await services.forms.submit('fm_1', {
      'f_1': '张小明',
      'f_2': '20250101',
      'f_3': ['o_1'],
      'f_4': 'o_4',
      'f_5': 1,
      'f_6': '',
      'f_7': '',
    });

    final after = await services.forms.list(filter: 'todo');
    expect(after.items.map((f) => f.title), isNot(contains('教材选购登记')));
  });

  test('提交后计数加一，再交一次是覆盖不是新增', () async {
    final services = await testServices();
    final before = await services.forms.detail('fm_1');
    expect(before.submissionCount, 2);
    expect(before.mySubmitted, isFalse);

    final submitted = await services.forms.submit('fm_1', {
      'f_1': '张小明',
      'f_2': '20250101',
      'f_3': ['o_1', 'o_3'],
      'f_4': 'o_4',
      'f_5': 2,
      'f_6': '2026-11-20',
      'f_7': '要开发票',
    });
    expect(submitted.mySubmitted, isTrue);
    expect(submitted.submissionCount, 3);
    expect(submitted.myAnswers['f_1'], '张小明');

    final again = await services.forms.submit('fm_1', {
      'f_1': '张小明',
      'f_2': '20250101',
      'f_3': ['o_2'],
      'f_4': 'o_5',
      'f_5': 1,
      'f_6': '',
      'f_7': '',
    });
    expect(again.submissionCount, 3, reason: '还是 3 份，没有多出一条');
    expect(again.myAnswers['f_4'], 'o_5');

    // 换建表人视角数一遍，确认没有多出一条。
    await signInAs(services, '20250102');
    final list = await services.forms.submissions('fm_1');
    expect(list.where((s) => s.userName == '张小明'), hasLength(1));
  });

  test('漏填必填项被服务端挡回，字段错误能定位', () async {
    final services = await testServices();

    await expectLater(
      services.forms.submit('fm_1', {'f_1': '张小明'}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'VALIDATION_FAILED')
            .having((e) => e.fieldErrors.containsKey('f_3'), '含 f_3', isTrue),
      ),
    );
  });

  test('学生不能建表，班委能建且应缴人数按本班算', () async {
    final student = await testServices();
    await expectLater(
      student.forms.create(title: '学生建的表', fields: _fields()),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'FORBIDDEN')),
    );

    final committee = await testServices(loginAs: '20250102');
    final form = await committee.forms.create(
      title: '国庆去向登记',
      description: '统计假期去向',
      fields: _fields(),
    );
    expect(form.title, '国庆去向登记');
    expect(form.fields, hasLength(2));
    expect(form.isMine, isTrue);
    // 软件2615 在种子里有 4 个人。
    expect(form.targetCount, 4);

    final mine = await committee.forms.list(filter: 'mine');
    expect(mine.items.map((f) => f.title), contains('国庆去向登记'));
  });

  test('有人提交后题目锁死，标题还能改', () async {
    final services = await testServices(loginAs: '20250102');

    await expectLater(
      services.forms.update('fm_1', fields: _fields()),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'FIELDS_LOCKED')),
    );

    final renamed = await services.forms.update(
      'fm_1',
      title: '教材选购登记（补收）',
    );
    expect(renamed.title, '教材选购登记（补收）');
    expect(renamed.fields, hasLength(7));
  });

  test('汇总只给建表人和管理员', () async {
    final services = await testServices();
    await expectLater(
      services.forms.submissions('fm_1'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'FORBIDDEN')),
    );

    await signInAs(services, '20250102');
    final rows = await services.forms.submissions('fm_1');
    expect(rows, hasLength(2));
    expect(rows.first.userName, isNotEmpty);

    await signInAs(services, '20250103');
    expect(await services.forms.submissions('fm_1'), hasLength(2));
  });

  test('关闭表单后不能再提交', () async {
    final services = await testServices(loginAs: '20250102');

    final closed = await services.forms.close('fm_1');
    expect(closed.status, FormStatus.closed);

    await signInAs(services, '20250101');
    await expectLater(
      services.forms.submit('fm_1', {
        'f_1': '张小明',
        'f_2': '20250101',
        'f_3': ['o_1'],
        'f_4': 'o_4',
        'f_5': 1,
      }),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'FORM_CLOSED')),
    );
  });

  test('催填只提醒本班还没交的人', () async {
    final services = await testServices(loginAs: '20250102');

    // 本班 4 人：李思远（建表人）、张小明、王老师没交，陈佳仪已交。
    final count = await services.forms.remind('fm_1');
    expect(count, 2);

    await signInAs(services, '20250101');
    final inbox = await services.messages.list();
    expect(inbox.items.any((m) => m.type.name == 'formReminder'), isTrue);
  });

  test('题目结构不合法会被拦：没有题目 / 单选项不够', () async {
    final services = await testServices(loginAs: '20250102');

    await expectLater(
      services.forms.create(title: '空表', fields: const []),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'VALIDATION_FAILED')),
    );

    await expectLater(
      services.forms.create(
        title: '只有一个选项的表',
        fields: const [
          FormFieldSpec(
            id: 'q1',
            type: FormFieldType.singleChoice,
            label: '选一个',
            options: [FormOption(id: 'a', label: '唯一')],
          ),
        ],
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'VALIDATION_FAILED')),
    );
  });
}
