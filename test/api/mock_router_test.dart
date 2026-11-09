import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/api/mock/mock_db.dart';
import 'package:yuki_blog_app/core/api/mock/mock_request.dart';
import 'package:yuki_blog_app/core/api/mock/mock_router.dart';
import 'package:yuki_blog_app/models/campus/campus_user.dart';

class _FakeBackend implements MockBackend {
  _FakeBackend() : db = CampusDb();

  @override
  final CampusDb db;

  @override
  T mutate<T>(T Function(CampusDb db) fn) => fn(db);

  @override
  IssuedToken issueSession(String userId) =>
      IssuedToken('t', DateTime(2030));

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

MockRequest _req(MockRouter router, String method, String path) => MockRequest(
      method: method,
      path: path,
      backend: _FakeBackend(),
    );

void main() {
  late MockRouter router;

  setUp(() {
    router = MockRouter();
    router.on('GET', '/activities', (req) => 'list');
    router.on('GET', '/activities/:id', (req) => 'detail:${req.param('id')}');
    router.on('POST', '/activities/:id/signup', (req) => 'signup:${req.param('id')}');
  });

  test('静态路径优先于同行段数的带参路径', () async {
    router.on('GET', '/activities/pending-review', (req) => 'pending');

    expect(await router.dispatch(_req(router, 'GET', '/activities/pending-review')),
        'pending');
  });

  test('带参路径能捕获参数', () async {
    expect(await router.dispatch(_req(router, 'GET', '/activities/ac_7')),
        'detail:ac_7');
    expect(
      await router.dispatch(_req(router, 'POST', '/activities/ac_7/signup')),
      'signup:ac_7',
    );
  });

  test('未注册的路径抛 404 NOT_FOUND', () async {
    expect(
      () => router.dispatch(_req(router, 'GET', '/nothing/here')),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.code, 'code', 'NOT_FOUND'),
      ),
    );
  });

  test('路径存在但方法不对抛 405', () async {
    expect(
      () => router.dispatch(_req(router, 'DELETE', '/activities')),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 405)
            .having((e) => e.code, 'code', 'METHOD_NOT_ALLOWED'),
      ),
    );
  });
}
