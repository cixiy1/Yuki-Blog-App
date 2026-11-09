import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/api/api_paths.dart';
import 'package:yuki_blog_app/core/api/campus_db_store.dart';
import 'package:yuki_blog_app/core/api/mock/mock_api_client.dart';
import 'package:yuki_blog_app/core/api/mock/mock_db.dart';
import 'package:yuki_blog_app/core/api/mock/mock_request.dart';
import 'package:yuki_blog_app/models/campus/json_utils.dart';

/// 每个用例一个全新的 Mock 后端：内存库，两次请求之间零延迟。
MockApiClient newMockApi({
  CampusDb? db,
  MockErrorInjector? injector,
  MemoryCampusDbStore? store,
}) {
  final backing = store ?? MemoryCampusDbStore(db?.toJson());
  return MockApiClient(
    store: backing,
    latency: Duration.zero,
    jitterMs: 0,
    injector: injector,
  );
}

/// 用演示账号登录，并把 token 挂到 client 上。
Future<String> loginAs(ApiClient api, {String studentId = '20250101'}) async {
  final result = await api.post(
    ApiPaths.login,
    body: {'studentId': studentId, 'password': '123456'},
  );
  final token = asString(asMap(result)['token']);
  api.authToken = token;
  return token;
}

const String kStudentId = '20250101';
