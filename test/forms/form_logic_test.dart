import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/form_answer_validator.dart';
import 'package:yuki_blog_app/core/campus/form_csv.dart';
import 'package:yuki_blog_app/models/campus/campus_form.dart';

FormFieldSpec _field({
  required String id,
  required FormFieldType type,
  String label = '题目',
  bool required = true,
  List<FormOption> options = const [],
  int? maxLength,
  num? min,
  num? max,
}) =>
    FormFieldSpec(
      id: id,
      type: type,
      label: label,
      required: required,
      options: options,
      maxLength: maxLength,
      min: min,
      max: max,
    );

void main() {
  group('答案校验', () {
    test('必填没填、选填可以空', () {
      final fields = [
        _field(id: 'f1', type: FormFieldType.singleLine, label: '姓名'),
        _field(
          id: 'f2',
          type: FormFieldType.singleLine,
          label: '备注',
          required: false,
        ),
      ];

      final errors = validateAnswers(fields, {'f2': '  '});
      expect(errors.keys, ['f1']);
      expect(errors['f1'], '姓名不能为空');
    });

    test('超出字数上限', () {
      final fields = [
        _field(
          id: 'f1',
          type: FormFieldType.multiLine,
          label: '说明',
          maxLength: 5,
        ),
      ];

      expect(validateAnswers(fields, {'f1': '一二三四五'}), isEmpty);
      expect(validateAnswers(fields, {'f1': '一二三四五六'})['f1'], '说明最多 5 字');
    });

    test('数字范围与学号格式', () {
      final num = _field(
        id: 'n',
        type: FormFieldType.number,
        label: '本数',
        min: 1,
        max: 10,
      );
      expect(validateAnswers([num], {'n': 0})['n'], '本数不能小于 1');
      expect(validateAnswers([num], {'n': 11})['n'], '本数不能大于 10');
      expect(validateAnswers([num], {'n': 'abc'})['n'], '本数只能填数字');
      expect(validateAnswers([num], {'n': 3}), isEmpty);

      final sid = _field(id: 's', type: FormFieldType.studentId, label: '学号');
      expect(validateAnswers([sid], {'s': '2025'})['s'], '学号应该是 8–12 位数字');
      expect(validateAnswers([sid], {'s': '20250101'}), isEmpty);
    });

    test('选项必须来自题目定义，多选逐项检查', () {
      final single = _field(
        id: 'c',
        type: FormFieldType.singleChoice,
        label: '领取方式',
        options: const [
          FormOption(id: 'o1', label: '自提'),
          FormOption(id: 'o2', label: '送宿舍'),
        ],
      );
      expect(validateAnswers([single], {'c': 'o1'}), isEmpty);
      expect(validateAnswers([single], {'c': 'o9'})['c'], '领取方式的选项不存在');

      final multi = _field(
        id: 'm',
        type: FormFieldType.multiChoice,
        label: '教材',
        options: const [
          FormOption(id: 'o1', label: '高数'),
          FormOption(id: 'o2', label: '英语'),
        ],
      );
      expect(validateAnswers([multi], {'m': ['o1', 'o2']}), isEmpty);
      expect(validateAnswers([multi], {'m': ['o1', 'x']})['m'], '教材的选项不存在');
    });

    test('规整答案：多选去重、文本去空白、空数字存空串', () {
      final fields = [
        _field(id: 't', type: FormFieldType.singleLine, required: false),
        _field(
          id: 'm',
          type: FormFieldType.multiChoice,
          required: false,
          options: const [
            FormOption(id: 'o1', label: 'A'),
            FormOption(id: 'o2', label: 'B'),
          ],
        ),
        _field(id: 'n', type: FormFieldType.number, required: false),
      ];

      final result = normalizeAnswers(fields, {
        't': '  张小明 ',
        'm': ['o1', 'o1', 'o2'],
        'n': '  ',
      });

      expect(result['t'], '张小明');
      expect(result['m'], ['o1', 'o2']);
      expect(result['n'], '');
    });
  });

  group('CSV 导出', () {
    final form = CampusForm(
      id: 'fm_1',
      title: '教材选购登记',
      description: '',
      fields: [
        _field(id: 'f1', type: FormFieldType.singleLine, label: '姓名'),
        _field(
          id: 'f2',
          type: FormFieldType.multiChoice,
          label: '教材',
          options: const [
            FormOption(id: 'o1', label: '高等数学（上）'),
            FormOption(id: 'o2', label: '英语, 综合教程'),
          ],
        ),
      ],
      creatorId: 'u_1002',
      creatorName: '李思远',
      createdAt: DateTime(2026, 11, 1),
    );

    final submission = FormSubmission(
      id: 'sb_1',
      formId: 'fm_1',
      userId: 'u_1004',
      userName: '陈佳仪',
      className: '软件2615',
      studentId: '20250104',
      answers: {
        'f1': '陈佳仪',
        'f2': ['o1', 'o2'],
      },
      submittedAt: DateTime(2026, 11, 2, 10, 30),
      updatedAt: DateTime(2026, 11, 2, 10, 30),
    );

    test('表头是提交人信息加每个题目', () {
      expect(formCsvHeader(form), ['提交人', '学号', '班级', '提交时间', '姓名', '教材']);
    });

    test('多选还原成选项文案，含逗号的裹引号', () {
      final csv = buildFormCsv(form, [submission]);
      final lines = csv.trim().split('\n');

      expect(lines, hasLength(2));
      expect(lines[1], contains('陈佳仪'));
      // 多选拼成一句话，里面带了逗号，整格裹引号。
      expect(lines[1], contains('"高等数学（上）、英语, 综合教程"'));
    });

    test('文件名去掉路径分隔符与空格', () {
      final name = formCsvFileName(form, now: DateTime(2026, 11, 9));
      expect(name, '表单-教材选购登记-20261109.csv');
    });
  });
}
