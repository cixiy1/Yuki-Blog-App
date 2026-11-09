import '../../models/campus/campus_user.dart';

/// 客户端能力清单。只用于隐藏 / 显示按钮，**不承担安全职责**——
/// 真正的 403 由服务端给出。
enum Capability {
  /// 发布活动（含编辑自己发起的）。
  createActivity,

  /// 审核活动（通过 / 驳回）。
  reviewActivity,

  /// 创建表单、关闭表单、催填。
  createForm,

  /// 查看表单汇总与导出。
  viewFormSummary,

  /// 查看活动报名名单。
  viewSignupList,

  /// 删除他人的帖子。
  deleteAnyPost,

  /// 重置演示数据。
  resetDemoData,
}

/// 角色 → 能力映射。改这里等于改整站的权限表达。
bool can(UserRole? role, Capability capability) {
  if (role == null) return false;

  final isAdmin = role == UserRole.admin;
  final isManager = role != UserRole.student;

  return switch (capability) {
    Capability.reviewActivity ||
    Capability.createActivity ||
    Capability.createForm ||
    Capability.viewFormSummary ||
    Capability.viewSignupList =>
      isManager,
    Capability.deleteAnyPost || Capability.resetDemoData => isAdmin,
  };
}

/// 三个角色在界面上统一的说明文案，设置页与登录页共用。
String roleDescription(UserRole role) => switch (role) {
      UserRole.student => '可浏览、发布、报名与接单',
      UserRole.committeeman => '额外可发起活动（需审核）、建表单、看汇总',
      UserRole.admin => '额外可审核活动、删他人内容、重置演示数据',
    };
