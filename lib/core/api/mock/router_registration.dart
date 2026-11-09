import 'handlers/auth_handlers.dart';
import 'handlers/media_handlers.dart';
import 'mock_router.dart';

/// 把各模块的 handler 挂到同一张路由表上。
/// 每加一个模块，只在这里加一行。
MockRouter buildMockRouter() {
  final router = MockRouter();
  registerAuthHandlers(router);
  registerMediaHandlers(router);
  return router;
}
