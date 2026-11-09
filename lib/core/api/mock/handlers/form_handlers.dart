import '../../../campus/form_answer_validator.dart';
import '../../../campus/permissions.dart';
import '../../../../models/campus/campus_form.dart';
import '../../../../models/campus/campus_user.dart';
import '../../../../models/campus/json_utils.dart';
import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';
import 'view_mappers.dart';

void registerFormHandlers(MockRouter r) {
  r.on('GET', ApiPaths.forms, _list);
  r.on('POST', ApiPaths.forms, _create);
  r.on('GET', '/forms/:id', _detail);
  r.on('PATCH', '/forms/:id', _update);
  r.on('POST', '/forms/:id/close', _close);
  r.on('GET', '/forms/:id/submissions', _submissions);
  r.on('POST', '/forms/:id/submissions', _submit);
  r.on('POST', '/forms/:id/remind', _remind);
}

String _now() => DateTime.now().toUtc().toIso8601String();

Object? _list(MockRequest req) {
  final user = requireUser(req);
  final uid = user.id;
  final db = req.backend.db;

  var rows = [
    for (final row in db.forms)
      if (visibleToUser(row, user, users: db.users)) row,
  ];

  final filter = req.query['filter'] ?? 'open';
  rows = switch (filter) {
    'all' => rows,
    'mine' => [
        for (final row in rows)
          if (row['creatorId'] == uid) row,
      ],
    'todo' => [
        for (final row in rows)
          if (row['status'] == 'open' && !_submitted(db.submissions, row, uid))
            row,
      ],
    _ => [
        for (final row in rows)
          if (row['status'] == 'open') row,
      ],
  };

  rows.sort(byNewest);

  return paginate(
    [for (final row in rows) formView(row, uid, db.submissions)],
    pageParam(req),
    pageSizeParam(req),
  );
}

Object? _detail(MockRequest req) {
  final user = requireUser(req);
  final row = findRow(req.backend.db.forms, req.param('id'), what: '表单');
  return formView(row, user.id, req.backend.db.submissions);
}

Object? _create(MockRequest req) {
  final user = requireRole(req);
  final body = req.json;

  final title =
      requiredString(body, 'title', label: '表单名称', maxLength: 40);
  final description = optionalString(body, 'description', maxLength: 500);
  final fields = _parseFields(body['fields']);
  final deadline = _parseDeadline(body['deadline']);
  final scope = _scope(body);

  return req.backend.mutate((db) {
    final row = <String, dynamic>{
      'id': db.nextId('fm'),
      'title': title,
      'description': description,
      'fields': fields,
      'creatorId': user.id,
      'creatorName': user.name,
      'deadline': deadline,
      'createdAt': _now(),
      'scope': scope,
      'status': 'open',
      'targetCount': _targetCount(db.users, user, scope == 'schoolWide'),
    };
    db.forms.add(row);
    return formView(row, user.id, db.submissions);
  });
}

Object? _update(MockRequest req) {
  final user = requireUser(req);
  final body = req.json;
  final isAdmin = can(user.role, Capability.deleteAnyPost);

  final preview = findRow(req.backend.db.forms, req.param('id'), what: '表单');
  _requireCreator(preview, user, isAdmin);
  final id = '${preview['id']}';

  final hasSubmissions =
      req.backend.db.submissions.any((s) => s['formId'] == id);
  final nextFields = body.containsKey('fields') ? _parseFields(body['fields']) : null;
  if (nextFields != null && hasSubmissions) {
    // 有人填过就不能再动结构：老答案会对不上新题目，统计也会串行。
    conflict('FIELDS_LOCKED', '已经有人提交了，题目不能再改');
  }

  return req.backend.mutate((db) {
    final row = findRow(db.forms, id, what: '表单');
    _requireCreator(row, user, isAdmin);

    if (body.containsKey('title')) {
      row['title'] =
          requiredString(body, 'title', label: '表单名称', maxLength: 40);
    }
    if (body.containsKey('description')) {
      row['description'] = optionalString(body, 'description', maxLength: 500);
    }
    if (body.containsKey('deadline')) {
      row['deadline'] = _parseDeadline(body['deadline']);
    }
    if (body.containsKey('scope')) {
      row['scope'] = _scope(body);
      row['targetCount'] =
          _targetCount(db.users, user, row['scope'] == 'schoolWide');
    }
    if (nextFields != null) row['fields'] = nextFields;

    return formView(row, user.id, db.submissions);
  });
}

Object? _close(MockRequest req) {
  final user = requireUser(req);
  final isAdmin = can(user.role, Capability.deleteAnyPost);
  final preview = findRow(req.backend.db.forms, req.param('id'), what: '表单');
  _requireCreator(preview, user, isAdmin);
  final id = '${preview['id']}';

  return req.backend.mutate((db) {
    final row = findRow(db.forms, id, what: '表单');
    _requireCreator(row, user, isAdmin);
    if (row['status'] == 'closed') conflict('BAD_STATUS', '这张表已经关闭了');
    row['status'] = 'closed';
    return formView(row, user.id, db.submissions);
  });
}

Object? _submissions(MockRequest req) {
  final user = requireUser(req);
  final row = findRow(req.backend.db.forms, req.param('id'), what: '表单');
  final isCreator = row['creatorId'] == user.id;
  if (!isCreator && !can(user.role, Capability.viewFormSummary)) {
    forbidden('只有建表人和管理员能看汇总');
  }

  final id = '${row['id']}';
  final rows = [
    for (final s in req.backend.db.submissions)
      if (s['formId'] == id) s,
  ]..sort(byNewest);

  return paginate(rows, pageParam(req), pageSizeParam(req));
}

Object? _submit(MockRequest req) {
  final user = requireUser(req);
  final id = '${req.param('id')}';

  final preview = findRow(req.backend.db.forms, id, what: '表单');
  if (preview['status'] != 'open') {
    conflict('FORM_CLOSED', '这张表已经关闭了，不能再提交');
  }

  final fields = _fieldsOf(preview);
  final raw = req.json['answers'];
  final answers = raw is Map ? raw.map((k, v) => MapEntry('$k', v)) : null;
  if (answers == null) invalid({'answers': '答案格式不对'});

  // 客户端已经校过一遍，服务端再校一遍——规则是同一份。
  final errors = validateAnswers(fields, answers);
  if (errors.isNotEmpty) invalid(errors, '有几处还需要修改');

  final normalized = normalizeAnswers(fields, answers);

  return req.backend.mutate((db) {
    final row = findRow(db.forms, id, what: '表单');
    if (row['status'] != 'open') {
      conflict('FORM_CLOSED', '这张表已经关闭了，不能再提交');
    }

    Map<String, dynamic>? mine;
    for (final s in db.submissions) {
      if (s['formId'] == id && s['userId'] == user.id) {
        mine = s;
        break;
      }
    }

    final target = mine ??
        <String, dynamic>{
          'id': db.nextId('sb'),
          'formId': id,
          'userId': user.id,
          'userName': user.name,
          'className': user.className,
          'studentId': user.studentId,
          'submittedAt': _now(),
        };

    target['answers'] = normalized;
    target['updatedAt'] = _now();
    if (mine == null) db.submissions.add(target);

    return formView(row, user.id, db.submissions);
  });
}

Object? _remind(MockRequest req) {
  final user = requireUser(req);
  final isAdmin = can(user.role, Capability.deleteAnyPost);
  final preview = findRow(req.backend.db.forms, req.param('id'), what: '表单');
  _requireCreator(preview, user, isAdmin);
  final id = '${preview['id']}';

  return req.backend.mutate((db) {
    final row = findRow(db.forms, id, what: '表单');
    if (row['status'] != 'open') conflict('FORM_CLOSED', '这张表已经关闭了');

    var reminded = 0;
    for (final u in db.users) {
      final uid = '${u['id']}';
      if (uid == user.id) continue;
      // 仅本班的表不打扰别班；全校的谁都能填。
      if (row['scope'] == 'classOnly' && u['className'] != user.className) {
        continue;
      }
      if (_submitted(db.submissions, row, uid)) continue;

      req.backend.pushMessage(
        userId: uid,
        title: '有张表还等着你填',
        body: '「${row['title']}」还没收到你的提交。',
        type: 'formReminder',
        refType: 'form',
        refId: id,
      );
      reminded++;
    }

    return {'reminded': reminded};
  });
}

// ── 校验与字段读取 ─────────────────────────────────────────

bool _submitted(
  List<Map<String, dynamic>> submissions,
  Map<String, dynamic> form,
  String uid,
) =>
    submissions.any((s) => s['formId'] == form['id'] && s['userId'] == uid);

void _requireCreator(
  Map<String, dynamic> row,
  CampusUser user,
  bool isAdmin,
) {
  if (row['creatorId'] != user.id && !isAdmin) {
    forbidden('只有建表人能改这张表');
  }
}

/// 把行里存的字段定义还原成模型，交给同一份校验规则。
List<FormFieldSpec> _fieldsOf(Map<String, dynamic> row) {
  final raw = row['fields'];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) FormFieldSpec.fromJson(item.cast<String, dynamic>()),
  ];
}

int _targetCount(
  List<Map<String, dynamic>> users,
  CampusUser creator,
  bool schoolWide,
) =>
    schoolWide
        ? users.length
        : users.where((u) => u['className'] == creator.className).length;

String? _parseDeadline(Object? raw) {
  if (raw == null) return null;
  final text = '$raw'.trim();
  if (text.isEmpty) return null;
  if (DateTime.tryParse(text) == null) {
    invalid({'deadline': '截止日期格式不对'});
  }
  // 只存到天的文案，界面上直接展示，不做时区换算。
  return text.length >= 10 ? text.substring(0, 10) : text;
}

String _scope(Map<String, dynamic> body) {
  final raw = body['scope'];
  if (raw == null) return 'classOnly';
  final value = '$raw';
  if (value != 'classOnly' && value != 'schoolWide') {
    invalid({'scope': '可见范围只能是 classOnly 或 schoolWide'});
  }
  return value;
}

/// 校验一份字段定义并补齐 id。
///
/// id 由客户端生成也行、不生成也行：缺了就按序号补 `f_1`、`f_2`，
/// 但同一张表里不能重名，否则答案的 key 会互相覆盖。
List<Map<String, dynamic>> _parseFields(Object? raw) {
  if (raw is! List || raw.isEmpty) {
    invalid({'fields': '至少要加一个题目'});
  }
  if (raw.length > 30) invalid({'fields': '一张表最多 30 个题目'});

  final out = <Map<String, dynamic>>[];
  final seen = <String>{};

  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) invalid({'fields': '第 ${i + 1} 个题目格式不对'});
    final map = item.cast<String, dynamic>();
    final index = i + 1;

    final type = enumByName(
      FormFieldType.values,
      map['type'],
      FormFieldType.singleLine,
    );
    final label = '${map['label'] ?? ''}'.trim();
    if (label.isEmpty) invalid({'fields': '第 $index 个题目还没写标题'});
    if (label.length > 40) invalid({'fields': '第 $index 个题目标题太长'});

    final id = '${map['id'] ?? ''}'.trim();
    final finalId = id.isEmpty ? 'f_$index' : id;
    if (!seen.add(finalId)) invalid({'fields': '题目 id 重复了：$finalId'});

    final options = <Map<String, dynamic>>[];
    if (type.isChoice) {
      final rawOptions = map['options'];
      final list = rawOptions is List ? rawOptions : const [];
      for (var o = 0; o < list.length; o++) {
        final option = list[o];
        final labelText = option is Map ? '${option['label'] ?? ''}'.trim() : '';
        if (labelText.isEmpty) continue;
        final optionId = option is Map ? '${option['id'] ?? ''}'.trim() : '';
        options.add({
          'id': optionId.isEmpty ? '${finalId}_o${o + 1}' : optionId,
          'label': labelText,
        });
      }
      if (options.length < 2) {
        invalid({'fields': '「$label」至少要两个选项'});
      }
    }

    final maxLength = map['maxLength'] is num
        ? (map['maxLength'] as num).toInt()
        : null;
    if (maxLength != null && (maxLength < 1 || maxLength > 2000)) {
      invalid({'fields': '「$label」的字数上限要在 1–2000 之间'});
    }

    out.add({
      'id': finalId,
      'type': type.name,
      'label': label,
      'required': map['required'] == true,
      'options': options,
      'hint': (map['hint'] is String && '${map['hint']}'.trim().isNotEmpty)
          ? '${map['hint']}'.trim()
          : null,
      'maxLength': maxLength,
      'min': map['min'] is num ? map['min'] : null,
      'max': map['max'] is num ? map['max'] : null,
    });
  }

  return out;
}
