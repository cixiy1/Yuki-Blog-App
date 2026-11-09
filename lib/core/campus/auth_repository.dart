import '../../models/campus/auth_session.dart';
import '../../models/campus/campus_user.dart';
import '../../models/campus/json_utils.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

abstract interface class AuthRepository {
  Future<AuthSession> login({
    required String studentId,
    required String password,
  });

  Future<AuthSession> register({
    required String studentId,
    required String password,
    required String name,
    required String className,
  });

  Future<CampusUser> me();

  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<AuthSession> login({
    required String studentId,
    required String password,
  }) async {
    final result = await _api.post(
      ApiPaths.login,
      body: {'studentId': studentId, 'password': password},
    );
    return AuthSession.fromJson(asMap(result));
  }

  @override
  Future<AuthSession> register({
    required String studentId,
    required String password,
    required String name,
    required String className,
  }) async {
    final result = await _api.post(
      ApiPaths.register,
      body: {
        'studentId': studentId,
        'password': password,
        'name': name,
        'className': className,
      },
    );
    return AuthSession.fromJson(asMap(result));
  }

  @override
  Future<CampusUser> me() async {
    final result = await _api.get(ApiPaths.me);
    return CampusUser.fromJson(asMap(result));
  }

  @override
  Future<void> logout() async {
    await _api.post(ApiPaths.logout);
  }
}
