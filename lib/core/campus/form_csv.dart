import '../../models/campus/campus_form.dart';
import '../../models/campus/json_utils.dart';

/// 表单汇总的 CSV 生成。
///
/// 纯函数，不碰文件系统——落盘 / 下载交给 file_exporter，
/// 这样表格内容本身可以单测，不用起模拟器。

/// 一行表头：提交人信息 + 每个题目一列。
List<String> formCsvHeader(CampusForm form) => [
      '提交人',
      '学号',
      '班级',
      '提交时间',
      for (final field in form.fields) field.label,
    ];

/// 一份提交 → 一行。
List<String> formCsvRow(CampusForm form, FormSubmission submission) => [
      submission.userName,
      submission.studentId,
      submission.className,
      _formatTime(submission.updatedAt),
      for (final field in form.fields) _answerText(field, submission.answers),
    ];

String buildFormCsv(CampusForm form, List<FormSubmission> submissions) {
  final buffer = StringBuffer();
  buffer.writeln(formCsvHeader(form).map(_escape).join(','));
  for (final submission in submissions) {
    buffer.writeln(formCsvRow(form, submission).map(_escape).join(','));
  }
  return buffer.toString();
}

/// `表单-教材选购登记-20261109.csv`
String formCsvFileName(CampusForm form, {DateTime? now}) {
  final time = now ?? DateTime.now();
  final stamp = '${time.year}'
      '${time.month.toString().padLeft(2, '0')}'
      '${time.day.toString().padLeft(2, '0')}';
  final safeTitle = form.title
      .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return '表单-${safeTitle.isEmpty ? form.id : safeTitle}-$stamp.csv';
}

/// 单选题存的是选项 id，导出要还原成人能读的文案。
String _answerText(FormFieldSpec field, Map<String, dynamic> answers) {
  final value = answers[field.id];
  if (_blank(value)) return '';

  if (field.type == FormFieldType.multiChoice) {
    final labels = [
      for (final item in asStringList(value))
        _optionLabel(field, item),
    ]..removeWhere((label) => label.isEmpty);
    return labels.join('、');
  }
  if (field.type == FormFieldType.singleChoice) {
    return _optionLabel(field, '$value');
  }
  if (value is List) return value.map((e) => '$e').join('、');
  return '$value';
}

String _optionLabel(FormFieldSpec field, String id) {
  for (final option in field.options) {
    if (option.id == id) return option.label;
  }
  return id;
}

bool _blank(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is List) return value.isEmpty;
  return false;
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// 逗号、引号、换行都要裹引号，内部引号翻倍。
String _escape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
