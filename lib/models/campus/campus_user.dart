import 'json_utils.dart';

/// 三档角色。学生只能参与，班委能发活动 / 建表单并审核，管理员额外可删他人内容。
enum UserRole {
  student('学生'),
  committeeman('班委'),
  admin('管理员');

  const UserRole(this.label);

  final String label;

  bool get canManage => this != UserRole.student;
  bool get canReview => this != UserRole.student;
}

/// 信用分档位。阈值与 `credit_engine.dart` 的公式配套。
enum CreditTier {
  excellent('优秀'),
  good('良好'),
  normal('一般'),
  low('待提升');

  const CreditTier(this.label);

  final String label;

  static CreditTier of(int score) {
    if (score >= 90) return CreditTier.excellent;
    if (score >= 75) return CreditTier.good;
    if (score >= 60) return CreditTier.normal;
    return CreditTier.low;
  }
}

/// 校园服务里的用户。唯一权威来源是 Mock 后端的 `users` 集合。
class CampusUser {
  const CampusUser({
    required this.id,
    required this.studentId,
    required this.name,
    required this.className,
    required this.role,
    this.creditScore = 70,
    this.reviewCount = 0,
    this.completedTasks = 0,
    this.avatarImageId,
    this.createdAt,
  });

  final String id;

  /// 学号，8-12 位数字。
  final String studentId;
  final String name;

  /// 班级名，如「软件2615」。
  final String className;
  final UserRole role;

  /// 信用分 0-100，由服务端按已完成单数与收到星级算出并缓存。
  final int creditScore;
  final int reviewCount;
  final int completedTasks;
  final String? avatarImageId;
  final DateTime? createdAt;

  CreditTier get creditTier => CreditTier.of(creditScore);

  /// 头像缺省时用姓名首字生成色块，不依赖网络图。
  /// 用 rune 取首字符，避免把代理对（表情等）切成半个字。
  String get avatarLetter =>
      name.isEmpty ? '?' : String.fromCharCode(name.runes.first);

  factory CampusUser.fromJson(Map<String, dynamic> json) => CampusUser(
        id: asString(json['id']),
        studentId: asString(json['studentId']),
        name: asString(json['name']),
        className: asString(json['className']),
        role: enumByName(UserRole.values, json['role'], UserRole.student),
        creditScore: asInt(json['creditScore'], 70),
        reviewCount: asInt(json['reviewCount']),
        completedTasks: asInt(json['completedTasks']),
        avatarImageId: asStringOrNull(json['avatarImageId']),
        createdAt: asDate(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'name': name,
        'className': className,
        'role': role.name,
        'creditScore': creditScore,
        'reviewCount': reviewCount,
        'completedTasks': completedTasks,
        'avatarImageId': avatarImageId,
        'createdAt': iso(createdAt),
      };

  CampusUser copyWith({
    String? name,
    String? className,
    UserRole? role,
    int? creditScore,
    int? reviewCount,
    int? completedTasks,
    String? avatarImageId,
  }) =>
      CampusUser(
        id: id,
        studentId: studentId,
        name: name ?? this.name,
        className: className ?? this.className,
        role: role ?? this.role,
        creditScore: creditScore ?? this.creditScore,
        reviewCount: reviewCount ?? this.reviewCount,
        completedTasks: completedTasks ?? this.completedTasks,
        avatarImageId: avatarImageId ?? this.avatarImageId,
        createdAt: createdAt,
      );
}
