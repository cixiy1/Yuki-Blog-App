import 'package:flutter/foundation.dart';

import '../../models/campus/auth_session.dart';
import '../../models/campus/campus_user.dart';
import '../api/api_client.dart';
import 'token_store.dart';

/// 登录态的唯一权威。
///
/// 用 [ChangeNotifier] 是因为 GoRouter 的 `refreshListenable` 只吃
/// `Listenable`；**只在登录态真的变化时才 notify**，否则路由会被
/// 无谓的刷新带着重定向。
class SessionController extends ChangeNotifier {
  SessionController({required this.store, required this.api}) {
    api.authToken = null;
  }

  final TokenStore store;
  final ApiClient api;

  AuthSession? _session;
  bool _restored = false;

  CampusUser? get user => _session?.user;
  String? get token => _session?.token;
  bool get isLoggedIn => _session != null && !(_session?.isExpired ?? true);
  bool get isRestored => _restored;

  /// 冷启动时从磁盘恢复登录态。已过期就地清理，不做静默续期。
  Future<void> restore() async {
    final saved = await store.load();
    if (saved != null && saved.isValid) {
      _session = saved;
      api.authToken = saved.token;
    } else if (saved != null) {
      await store.clear();
    }
    _restored = true;
    notifyListeners();
  }

  /// 登录 / 注册成功后写入。
  Future<void> establish(AuthSession session) async {
    _session = session;
    api.authToken = session.token;
    await store.save(session);
    notifyListeners();
  }

  /// 用户主动退出。
  Future<void> logout() async {
    _session = null;
    api.authToken = null;
    await store.clear();
    notifyListeners();
  }

  /// token 被服务端判定失效（401）时调用。只清本地，不重复请求。
  Future<void> expire() async {
    if (_session == null) return;
    _session = null;
    api.authToken = null;
    await store.clear();
    notifyListeners();
  }

  /// 用户在别处被更新（比如信用分变了），刷新本地快照。
  Future<void> updateUser(CampusUser user) async {
    final current = _session;
    if (current == null) return;
    final next = current.copyWith(user: user);
    _session = next;
    await store.save(next);
    notifyListeners();
  }
}
