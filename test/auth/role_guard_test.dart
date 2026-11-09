import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/api/mock/mock_db.dart';
import 'package:yuki_blog_app/core/api/mock/mock_request.dart';
import 'package:yuki_blog_app/core/api/mock/mock_support.dart';
import 'package:yuki_blog_app/models/campus/campus_user.dart';

class _Backend implements MockBackend {
  _Backend() : db = CampusDb();

  @override
  final CampusDb db;

  @override
  T mutate<T>(T Function(CampusDb db) fn) => fn(db);

  @override
  IssuedToken issueSession(String userId) => IssuedToken('t', DateTime(2030));

  @override
  void revokeToken(String token) {}

  @override
  CampusUser? userForToken(String token) => null;

  @override
  void pushMessage({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String refType,
    String? refId,
  }) {}
}

CampusUser _user(UserRole role) => CampusUser(
      id: 'u_1',
      studentId: '20250101',
      name: '测试',
      className: '软件2615',
      role: role,
    );

MockRequest _req({CampusUser? user}) => MockRequest(
      method: 'POST',
      path: '/test',
      backend: _Backend(),
      user: user,
    );

void main() {
  test('未登录时 requireUser 抛 401', () {
    expect(
      () => requireUser(_req()),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.code, 'code', 'UNAUTHORIZED')),
    );
  });

  test('学生调班委级接口抛 403', () {
    expect(
      () => requireRole(_req(user: _user(UserRole.student))),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 403)
          .having((e) => e.code, 'code', 'FORBIDDEN')),
    );
  });

  test('班委能过班委级校验', () {
    final user = requireRole(_req(user: _user(UserRole.committeeman)));
    expect(user.role, UserRole.committeeman);
  });

  test('管理员能过管理员级校验', () {
    final user = requireRole(
      _req(user: _user(UserRole.admin)),
      min: UserRole.admin,
    );
    expect(user.role, UserRole.admin);
  });

  test('班委过不了管理员级校验', () {
    expect(
      () => requireRole(
        _req(user: _user(UserRole.committeeman)),
        min: UserRole.admin,
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 403)),
    );
  });

  test('requiredString 对空值抛 422 并指向字段', () {
    expect(
      () => requiredString({'title': '  '}, 'title', label: '标题'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.fieldErrors, 'fieldErrors',
              containsPair('title', '标题不能为空'))),
    );
  });
}
