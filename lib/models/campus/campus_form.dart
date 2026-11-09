import 'campus_scope.dart';
import 'json_utils.dart';

/// 表单字段类型。值类型与 `form_answer_validator.dart` 的约定一一对应：
/// - 文本类 / 单选 / 日期 / 学号 → String
/// - 多选 → List&lt;String&gt;（选项 id）
/// - 数字 → num
enum FormFieldType {
  singleLine('单行文本'),
  multiLine('多行文本'),
  singleChoice('单选'),
  multiChoice('多选'),
  number('数字'),
  date('日期'),
  studentId('学号');

  const FormFieldType(this.label);

  final String label;

  bool get isChoice => this == singleChoice || this == multiChoice;
  bool get isText => this == singleLine || this == multiLine;
}

/// 选项用 id + label 存，改文案不影响历史提交的统计归属。
class FormOption {
  const FormOption({required this.id, required this.label});

  final String id;
  final String label;

  factory FormOption.fromJson(Map<String, dynamic> json) => FormOption(
        id: asString(json['id']),
        label: asString(json['label']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  FormOption copyWith({String? label}) =>
      FormOption(id: id, label: label ?? this.label);
}

/// 一个字段的定义。id 在建表时生成，之后永不改。
class FormFieldSpec {
  const FormFieldSpec({
    required this.id,
    required this.type,
    required this.label,
    this.required = false,
    this.options = const [],
    this.hint,
    this.maxLength,
    this.min,
    this.max,
  });

  final String id;
  final FormFieldType type;
  final String label;
  final bool required;
  final List<FormOption> options;

  /// 输入框占位文案。
  final String? hint;
  final int? maxLength;

  /// 数字类的最小 / 最大值。
  final num? min;
  final num? max;

  factory FormFieldSpec.fromJson(Map<String, dynamic> json) => FormFieldSpec(
        id: asString(json['id']),
        type: enumByName(
            FormFieldType.values, json['type'], FormFieldType.singleLine),
        label: asString(json['label']),
        required: asBool(json['required']),
        options: [
          for (final row in asMapList(json['options']))
            FormOption.fromJson(row),
        ],
        hint: asStringOrNull(json['hint']),
        maxLength: json['maxLength'] == null ? null : asInt(json['maxLength']),
        min: json['min'] == null ? null : asNum(json['min']),
        max: json['max'] == null ? null : asNum(json['max']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'label': label,
        'required': required,
        'options': [for (final o in options) o.toJson()],
        'hint': hint,
        'maxLength': maxLength,
        'min': min,
        'max': max,
      };

  FormFieldSpec copyWith({
    FormFieldType? type,
    String? label,
    bool? required,
    List<FormOption>? options,
    String? hint,
    int? maxLength,
    num? min,
    num? max,
    bool clearMaxLength = false,
    bool clearMin = false,
    bool clearMax = false,
  }) =>
      FormFieldSpec(
        id: id,
        type: type ?? this.type,
        label: label ?? this.label,
        required: required ?? this.required,
        options: options ?? this.options,
        hint: hint ?? this.hint,
        maxLength: clearMaxLength ? null : (maxLength ?? this.maxLength),
        min: clearMin ? null : (min ?? this.min),
        max: clearMax ? null : (max ?? this.max),
      );
}

enum FormStatus {
  open('进行中'),
  closed('已结束');

  const FormStatus(this.label);

  final String label;
}

/// 一张可填报的表。字段结构一旦有人提交就锁死（服务端 409）。
class CampusForm {
  const CampusForm({
    required this.id,
    required this.title,
    required this.description,
    required this.fields,
    required this.creatorId,
    required this.creatorName,
    required this.createdAt,
    this.scope = VisibilityScope.classOnly,
    this.deadline,
    this.status = FormStatus.open,
    this.submissionCount = 0,
    this.targetCount = 0,
    this.mySubmitted = false,
    this.isMine = false,
  });

  final String id;
  final String title;
  final String description;
  final List<FormFieldSpec> fields;
  final String creatorId;
  final String creatorName;
  final String? deadline;
  final DateTime createdAt;
  final VisibilityScope scope;
  final FormStatus status;
  final int submissionCount;

  /// 应交人数（本班人数），用于「已收 8/50」。
  final int targetCount;
  final bool mySubmitted;
  final bool isMine;

  bool get isOpen => status == FormStatus.open;

  String get deadlineText => deadline ?? '';

  factory CampusForm.fromJson(Map<String, dynamic> json) => CampusForm(
        id: asString(json['id']),
        title: asString(json['title']),
        description: asString(json['description']),
        fields: [
          for (final row in asMapList(json['fields'])) FormFieldSpec.fromJson(row),
        ],
        creatorId: asString(json['creatorId']),
        creatorName: asString(json['creatorName']),
        deadline: asStringOrNull(json['deadline']),
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
        scope: enumByName(
            VisibilityScope.values, json['scope'], VisibilityScope.classOnly),
        status: enumByName(FormStatus.values, json['status'], FormStatus.open),
        submissionCount: asInt(json['submissionCount']),
        targetCount: asInt(json['targetCount']),
        mySubmitted: asBool(json['mySubmitted']),
        isMine: asBool(json['isMine']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'fields': [for (final f in fields) f.toJson()],
        'creatorId': creatorId,
        'creatorName': creatorName,
        'deadline': deadline,
        'createdAt': iso(createdAt),
        'scope': scope.name,
        'status': status.name,
        'submissionCount': submissionCount,
        'targetCount': targetCount,
        'mySubmitted': mySubmitted,
        'isMine': isMine,
      };
}

/// 一份填报结果。[answers] 的 key 是字段 id。
class FormSubmission {
  const FormSubmission({
    required this.id,
    required this.formId,
    required this.userId,
    required this.userName,
    required this.className,
    required this.studentId,
    required this.answers,
    required this.submittedAt,
    required this.updatedAt,
  });

  final String id;
  final String formId;
  final String userId;
  final String userName;
  final String className;
  final String studentId;
  final Map<String, dynamic> answers;
  final DateTime submittedAt;
  final DateTime updatedAt;

  factory FormSubmission.fromJson(Map<String, dynamic> json) => FormSubmission(
        id: asString(json['id']),
        formId: asString(json['formId']),
        userId: asString(json['userId']),
        userName: asString(json['userName']),
        className: asString(json['className']),
        studentId: asString(json['studentId']),
        answers: asMap(json['answers']),
        submittedAt: asDate(json['submittedAt']) ?? DateTime.now(),
        updatedAt: asDate(json['updatedAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'formId': formId,
        'userId': userId,
        'userName': userName,
        'className': className,
        'studentId': studentId,
        'answers': answers,
        'submittedAt': iso(submittedAt),
        'updatedAt': iso(updatedAt),
      };
}
