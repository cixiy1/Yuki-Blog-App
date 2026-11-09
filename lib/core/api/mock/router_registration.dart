import 'handlers/activity_handlers.dart';
import 'handlers/auth_handlers.dart';
import 'handlers/express_handlers.dart';
import 'handlers/form_handlers.dart';
import 'handlers/lost_found_handlers.dart';
import 'handlers/market_handlers.dart';
import 'handlers/media_handlers.dart';
import 'handlers/message_handlers.dart';
import 'handlers/portal_handlers.dart';
import 'handlers/purchase_handlers.dart';
import 'mock_router.dart';

/// 把各模块的 handler 挂到同一张路由表上。
/// 每加一个模块，只在这里加一行。
MockRouter buildMockRouter() {
  final router = MockRouter();
  registerActivityHandlers(router);
  registerAuthHandlers(router);
  registerMediaHandlers(router);
  registerPortalHandlers(router);
  registerMessageHandlers(router);
  registerLostFoundHandlers(router);
  registerMarketHandlers(router);
  registerExpressHandlers(router);
  registerFormHandlers(router);
  registerPurchaseHandlers(router);
  return router;
}
