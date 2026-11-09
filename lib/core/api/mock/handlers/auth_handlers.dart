import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';

final RegExp _studentIdPattern = RegExp(r'^\d{8,12}$');

/// 去掉密码等敏感字段，只回传可以给前端看的用户信息。
Map<String, dynamic> publicUser(Map<String, dynamic> row) => {
      for (final e in row.entries)
        if (e.key != 'password') e.key: e.value,
    };

void registerAuthHandlers(MockRouter r) {
  r.on('POST', ApiPaths.login, _login);
  r.on('POST', ApiPaths.register, _register);
  r.on('GET', ApiPaths.me, _me);
  r.on('POST', ApiPaths.logout, _logout);
  r.on('GET', '/users/:id', _userDetail);
}

Object? _login(MockRequest req) {
  final studentId =
      requiredString(req.json, 'studentId', label: '学号', maxLength: 12);
  final password =
      requiredString(req.json, 'password', label: '密码', maxLength: 64);

  if (!_studentIdPattern.hasMatch(studentId)) {
    invalid({'studentId': '学号需 8-12 位数字'});
  }
  if (password.length < 6) {
    invalid({'password': '密码至少 6 位'});
  }

  Map<String, dynamic>? row;
  for (final u in req.backend.db.users) {
    if (u['studentId'] == studentId) {
      row = u;
      break;
    }
  }
  // 账号不存在与密码错误返回同一句话，不泄露学号是否注册过。
  if (row == null || row['password'] != password) {
    unauthorized('学号或密码不正确');
  }

  final issued = req.backend.issueSession(row['id'] as String);
  return {
    'token': issued.token,
    'expiresAt': issued.expiresAt.toIso8601String(),
    'user': publicUser(row),
  };
}

Object? _register(MockRequest req) {
  final studentId =
      requiredString(req.json, 'studentId', label: '学号', maxLength: 12);
  final password =
      requiredString(req.json, 'password', label: '密码', maxLength: 64);
  final name = requiredString(req.json, 'name', label: '姓名', maxLength: 20);
  final className = requiredString(req.json, 'className',
      label: '班级', maxLength: 20);

  if (!_studentIdPattern.hasMatch(studentId)) {
    invalid({'studentId': '学号需 8-12 位数字'});
  }
  if (password.length < 6) {
    invalid({'password': '密码至少 6 位'});
  }
  if (req.backend.db.users.any((u) => u['studentId'] == studentId)) {
    conflict('STUDENT_ID_TAKEN', '该学号已注册，请直接登录');
  }

  final row = req.backend.mutate((db) {
    final created = <String, dynamic>{
      'id': db.nextId('u'),
      'studentId': studentId,
      'password': password,
      'name': name,
      'className': className,
      'role': 'student',
      'creditScore': 70,
      'reviewCount': 0,
      'completedTasks': 0,
      'avatarImageId': null,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    db.users.add(created);
    return created;
  });

  final issued = req.backend.issueSession(row['id'] as String);
  return {
    'token': issued.token,
    'expiresAt': issued.expiresAt.toIso8601String(),
    'user': publicUser(row),
  };
}

Object? _me(MockRequest req) {
  final user = requireUser(req);
  for (final u in req.backend.db.users) {
    if (u['id'] == user.id) return publicUser(u);
  }
  unauthorized('账号已不存在');
}

Object? _logout(MockRequest req) {
  requireUser(req);
  final token = req.token;
  if (token != null) req.backend.revokeToken(token);
  return {'ok': true};
}

Object? _userDetail(MockRequest req) {
  requireUser(req);
  final id = req.param('id');
  final row = findRow(req.backend.db.users, id, what: '用户');

  final reviews = [
    for (final r in req.backend.db.reviews)
      if (r['toUserId'] == id) r,
  ]..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));

  return {
    'user': publicUser(row),
    'recentReviews': reviews.take(5).toList(),
  };
}
