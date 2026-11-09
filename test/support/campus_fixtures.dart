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
    await signInAs(services, loginAs);
    await services.refreshUnread();
  }
  return services;
}

/// 在同一套后端上换一个账号——模拟「另一个人」接着操作。
///
/// 涉及双人协作的模块（接单、互评）都靠它造场景，
/// 不用再造第二个客户端，数据也不会分成两个库。
Future<void> signInAs(CampusServices services, String studentId) async {
  final issued = await services.auth.login(
    studentId: studentId,
    password: '123456',
  );
  await services.session.establish(issued);
}
