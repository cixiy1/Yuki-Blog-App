import 'campus_user.dart';
import 'json_utils.dart';

/// 登录态：假 token + 过期时间 + 用户快照。
///
/// token 本身是 Mock 后端签的假 JWT，格式见 `mock/handlers/auth_handlers.dart`。
/// 客户端只用它做「本地先判过期」的优化，是否有效最终以服务端 session 表为准。
class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  final String token;
  final DateTime expiresAt;
  final CampusUser user;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isValid => !isExpired;

  AuthSession copyWith({CampusUser? user}) => AuthSession(
        token: token,
        expiresAt: expiresAt,
        user: user ?? this.user,
      );

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: asString(json['token']),
        expiresAt: asDate(json['expiresAt']) ??
            DateTime.now().add(const Duration(days: 7)),
        user: CampusUser.fromJson(asMap(json['user'])),
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'expiresAt': iso(expiresAt),
        'user': user.toJson(),
      };
}
