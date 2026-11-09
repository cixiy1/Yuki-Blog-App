import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/api/api_paths.dart';
import 'package:yuki_blog_app/core/campus/auth_repository.dart';

import '../support/mock_fixtures.dart';

void main() {
  late ApiAuthRepository repo;
  late ApiClient api;

  setUp(() {
    api = newMockApi();
    repo = ApiAuthRepository(api);
  });

  test('演示账号能正常登录并拿到 token', () async {
    final session = await repo.login(studentId: kStudentId, password: '123456');

    expect(session.token, isNotEmpty);
    expect(session.user.studentId, kStudentId);
    expect(session.user.name, '张小明');
    expect(session.isValid, isTrue);
  });

  test('密码错误返回 401，且不泄露学号是否存在', () async {
    expect(
      () => repo.login(studentId: kStudentId, password: 'wrong-pass'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', '学号或密码不正确')),
    );

    expect(
      () => repo.login(studentId: '20999999', password: '123456'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', '学号或密码不正确')),
    );
  });

  test('学号格式不对返回 422，并指向具体字段', () async {
    expect(
      () => repo.login(studentId: 'abc', password: '123456'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.fieldErrors, 'fieldErrors',
              containsPair('studentId', '学号需 8-12 位数字'))),
    );
  });

  test('重复学号注册返回 409 STUDENT_ID_TAKEN', () async {
    expect(
      () => repo.register(
        studentId: kStudentId,
        password: '123456',
        name: '冒名',
        className: '软件2615',
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.code, 'code', 'STUDENT_ID_TAKEN')),
    );
  });

  test('token 无效时 /auth/me 返回 401', () async {
    await loginAs(api);
    api.authToken = 'mock.v1.u_1001.1.deadbeef';

    expect(
      () => repo.me(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 401)),
    );
  });

  test('注册后可以拿到自己的资料，且密码不外泄', () async {
    final session = await repo.register(
      studentId: '20260777',
      password: 'abc123',
      name: '新同学',
      className: '软件2616',
    );
    expect(session.user.role.name, 'student', reason: '自助注册一律是学生');

    api.authToken = session.token;
    final me = await repo.me();
    expect(me.name, '新同学');
    expect(me.className, '软件2616');
    expect(me.toJson().containsKey('password'), isFalse);
  });

  test('登出后原 token 立即失效', () async {
    final token = await loginAs(api);
    await repo.logout();

    api.authToken = token;
    expect(
      () => repo.me(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 401)),
    );
  });
}
