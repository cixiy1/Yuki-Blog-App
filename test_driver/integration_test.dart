import 'package:integration_test/integration_test_driver.dart';

/// `flutter drive` 的驱动入口：只负责把集成测试里的 performance summary
/// 写进 `build/` 并回报结果，不含任何业务逻辑。
///
/// ```sh
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/scroll_perf_test.dart \
///   -d macos --profile
/// ```
Future<void> main() => integrationDriver();
