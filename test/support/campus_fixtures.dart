import 'package:yuki_blog_app/core/api/campus_db_store.dart';
import 'package:yuki_blog_app/core/api/json_store_memory.dart';
import 'package:yuki_blog_app/core/api/mock/mock_api_client.dart';
import 'package:yuki_blog_app/core/campus/campus_services.dart';
import 'package:yuki_blog_app/core/campus/session_controller.dart';
import 'package:yuki_blog_app/core/campus/token_store.dart';

/// 造一套跑在内存里的完整服务，供 widget 测试用。
///
/// 传 [loginAs] 就等于「已经登录了该学号」，不需要再走登录页。
Future<CampusServices> testServices({String? loginAs = '20250101'}) async {
  final api = MockApiClient(
    store: MemoryCampusDbStore(),
    latency: Duration.zero,
    jitterMs: 0,
  );
  await api.ensureLoaded();

  final session = SessionController(
    store: TokenStore(store: MemoryJsonStore()),
    api: api,
  );
  await session.restore();

  final services = CampusServices(api: api, session: session);
  if (loginAs != null) {
    final issued = await services.auth.login(
      studentId: loginAs,
      password: '123456',
    );
    await session.establish(issued);
    await services.refreshUnread();
  }
  return services;
}
