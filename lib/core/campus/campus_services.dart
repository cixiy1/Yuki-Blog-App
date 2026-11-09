import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/campus_db_store.dart';
import '../api/mock/mock_api_client.dart';
import 'auth_repository.dart';
import 'media_repository.dart';
import 'message_repository.dart';
import 'session_controller.dart';
import 'token_store.dart';

/// 校园服务的全局门面。
///
/// 页面通过构造函数接收它（`services` 参数）便于测试注入；
/// 运行期用 [CampusServices.instance] 拿同一个实例。
/// 换真后端只需要改 [bootstrap] 里 `MockApiClient(...)` 那一行。
class CampusServices {
  CampusServices({required this.api, required this.session});

  static CampusServices? _instance;

  /// 未登录时也可能需要读它，所以提供 isReady 让路由守卫先判空。
  static bool get isReady => _instance != null;

  static CampusServices get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('CampusServices.bootstrap() 还没执行');
    }
    return value;
  }

  /// 应用启动时调一次：建库 / 恢复登录态 / 拉未读数。
  static Future<CampusServices> bootstrap() async {
    final existing = _instance;
    if (existing != null) return existing;

    final api = MockApiClient(store: JsonCampusDbStore());
    await api.ensureLoaded();

    final session = SessionController(store: TokenStore(), api: api);
    api.onUnauthorized = () => unawaited(session.expire());
    await session.restore();

    final services = CampusServices(api: api, session: session);
    unawaited(services.refreshUnread());
    _instance = services;
    return services;
  }

  /// 测试用：清掉单例，别让用例之间串数据。
  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance = null;
  }

  final ApiClient api;
  final SessionController session;

  /// 未读消息数。底栏角标和门户红点都监听它，避免整页重建。
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  late final AuthRepository auth = ApiAuthRepository(api);
  late final MediaRepository media = ApiMediaRepository(api);
  late final MessageRepository messages = ApiMessageRepository(api);

  /// 拉一次未读数。失败静默——角标不显示比报错好。
  Future<void> refreshUnread() async {
    if (!session.isLoggedIn) {
      unread.value = 0;
      return;
    }
    try {
      unread.value = await messages.unreadCount();
    } catch (_) {
      // 未读数拿不到不影响主流程
    }
  }

  /// 清库重播 + 退出登录。仅管理员可见的入口会调它。
  Future<void> resetDemoData() async {
    final client = api;
    if (client is MockApiClient) {
      await client.resetDemoData();
    }
    await session.logout();
    unread.value = 0;
  }

  void dispose() {
    unread.dispose();
    session.dispose();
    api.dispose();
    if (identical(_instance, this)) _instance = null;
  }
}
