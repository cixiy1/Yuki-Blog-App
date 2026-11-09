import '../../models/campus/auth_session.dart';
import '../api/json_store.dart';

/// 登录态的持久化。原生写 `<docs>/campus/session.json`，
/// Web 写 `localStorage['campus.v1.session']`。
class TokenStore {
  TokenStore({JsonStore? store, this.key = 'session'})
      : _store = store ?? createJsonStore();

  final JsonStore _store;
  final String key;

  Future<AuthSession?> load() async {
    final raw = await _store.read(key);
    if (raw == null) return null;
    try {
      final session = AuthSession.fromJson(raw);
      if (session.token.isEmpty) return null;
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AuthSession session) => _store.write(key, session.toJson());

  Future<void> clear() => _store.delete(key);
}
