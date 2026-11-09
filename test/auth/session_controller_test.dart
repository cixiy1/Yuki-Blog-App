import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/api/mock/mock_api_client.dart';
import 'package:yuki_blog_app/core/api/json_store_memory.dart';
import 'package:yuki_blog_app/core/campus/auth_repository.dart';
import 'package:yuki_blog_app/core/campus/session_controller.dart';
import 'package:yuki_blog_app/core/campus/token_store.dart';
import 'package:yuki_blog_app/models/campus/auth_session.dart';
import 'package:yuki_blog_app/models/campus/campus_user.dart';

import '../support/mock_fixtures.dart';

void main() {
  late MemoryJsonStore backend;
  late TokenStore tokenStore;
  late MockApiClient api;
  late SessionController session;

  setUp(() {
    backend = MemoryJsonStore();
    tokenStore = TokenStore(store: backend);
    api = newMockApi();
    session = SessionController(store: tokenStore, api: api);
  });

  test('登录后写入本地，新实例能恢复登录态', () async {
    final repo = ApiAuthRepository(api);
    final fresh = await repo.login(studentId: kStudentId, password: '123456');
    await session.establish(fresh);

    expect(session.isLoggedIn, isTrue);
    expect(backend.snapshot.containsKey('session'), isTrue);

    // 模拟冷启动：同一个 store 造一个新 controller。
    final restored = SessionController(store: tokenStore, api: api);
    await restored.restore();
    expect(restored.isLoggedIn, isTrue);
    expect(restored.user?.studentId, kStudentId);
  });

  test('本地存的是过期会话时，恢复后判定为未登录并清掉', () async {
    await tokenStore.save(
      AuthSession(
        token: 'mock.v1.u_1001.1.deadbeef',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        user: const CampusUser(
          id: 'u_1001',
          studentId: kStudentId,
          name: '张小明',
          className: '软件2615',
          role: UserRole.student,
        ),
      ),
    );

    await session.restore();

    expect(session.isLoggedIn, isFalse);
    expect(backend.snapshot.containsKey('session'), isFalse);
  });

  test('登出清空本地会话与 client 上的 token', () async {
    final repo = ApiAuthRepository(api);
    await session.establish(
      await repo.login(studentId: kStudentId, password: '123456'),
    );
    expect(api.authToken, isNotNull);

    await session.logout();

    expect(session.isLoggedIn, isFalse);
    expect(api.authToken, isNull);
    expect(backend.snapshot.containsKey('session'), isFalse);
  });

  test('token 失效时 expire 只清本地，不改服务端数据', () async {
    final repo = ApiAuthRepository(api);
    await session.establish(
      await repo.login(studentId: kStudentId, password: '123456'),
    );
    final before = api.db.users.length;

    await session.expire();

    expect(session.isLoggedIn, isFalse);
    expect(api.db.users.length, before);
  });

  test('切换账号后看到的是同一份数据', () async {
    final repo = ApiAuthRepository(api);
    await session.establish(
      await repo.login(studentId: kStudentId, password: '123456'),
    );
    await api.post('/auth/register', body: {
      'studentId': '20260666',
      'password': '123456',
      'name': '另一个人',
      'className': '软件2616',
    });
    final countAfterCreate = api.db.users.length;

    await session.logout();
    await session.establish(
      await repo.login(studentId: '20250102', password: '123456'),
    );

    expect(session.user?.name, '李思远');
    expect(api.db.users.length, countAfterCreate,
        reason: '换账号不该重置或复制整库');
  });
}
