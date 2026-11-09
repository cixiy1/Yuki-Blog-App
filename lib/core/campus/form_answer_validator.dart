import '../../models/campus/campus_form.dart';

// 表单答案校验。
//
// 客户端用它即时提示，服务端用同一份规则再校一次——规则只有一处，
// 不会出现「前端放行、后端拒绝」的对不上。

/// 学号格式：8–12 位数字。
final RegExp kStudentIdPattern = RegExp(r'^\d{8,12}$');

/// 答案是否算「没填」。
bool isEmptyAnswer(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is List) {
    return value.where((e) => e != null && '$e'.isNotEmpty).isEmpty;
  }
  return false;
}

/// 校验整张表。返回 `字段 id → 错误文案`，空 Map 表示全部通过。
Map<String, String> validateAnswers(
  List<FormFieldSpec> fields,
  Map<String, dynamic> answers,
) {
  final errors = <String, String>{};

  for (final field in fields) {
    final value = answers[field.id];

    if (isEmptyAnswer(value)) {
      if (field.required) errors[field.id] = '${field.label}不能为空';
      continue;
    }

    switch (field.type) {
      case FormFieldType.singleLine:
      case FormFieldType.multiLine:
        final text = '$value';
        final max = field.maxLength;
        if (max != null && text.runes.length > max) {
          errors[field.id] = '${field.label}最多 $max 字';
        }
      case FormFieldType.number:
        final number = value is num ? value : num.tryParse('$value');
        if (number == null) {
          errors[field.id] = '${field.label}只能填数字';
          break;
        }
        if (field.min != null && number < field.min!) {
          errors[field.id] = '${field.label}不能小于 ${_trim(field.min!)}';
        } else if (field.max != null && number > field.max!) {
          errors[field.id] = '${field.label}不能大于 ${_trim(field.max!)}';
        }
      case FormFieldType.date:
        if (DateTime.tryParse('$value') == null) {
          errors[field.id] = '${field.label}的日期格式不对';
        }
      case FormFieldType.studentId:
        if (!kStudentIdPattern.hasMatch('$value')) {
          errors[field.id] = '${field.label}应该是 8–12 位数字';
        }
      case FormFieldType.singleChoice:
        if (!_hasOption(field, '$value')) {
          errors[field.id] = '${field.label}的选项不存在';
        }
      case FormFieldType.multiChoice:
        final picked = value is List ? value : <Object?>[value];
        for (final item in picked) {
          if (!_hasOption(field, '$item')) {
            errors[field.id] = '${field.label}的选项不存在';
            break;
          }
        }
    }
  }

  return errors;
}

/// 把答案规整成可存的形状：多选去空去重，文本去首尾空白。
Map<String, dynamic> normalizeAnswers(
  List<FormFieldSpec> fields,
  Map<String, dynamic> answers,
) {
  final result = <String, dynamic>{};

  for (final field in fields) {
    final value = answers[field.id];

    if (field.type == FormFieldType.multiChoice) {
      final picked = <String>{
        if (value is List)
          for (final item in value)
            if (item != null && '$item'.isNotEmpty) '$item',
      }.toList();
      result[field.id] = picked;
    } else if (field.type == FormFieldType.number) {
      if (value == null || '$value'.trim().isEmpty) {
        result[field.id] = '';
      } else {
        result[field.id] = value is num ? value : num.tryParse('$value') ?? 0;
      }
    } else if (value is String) {
      result[field.id] = value.trim();
    } else {
      result[field.id] = value ?? '';
    }
  }

  return result;
}

/// 12.0 显示成 12，12.5 保持 12.5。
String _trim(num value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';

bool _hasOption(FormFieldSpec field, String id) =>
    field.options.any((option) => option.id == id);
