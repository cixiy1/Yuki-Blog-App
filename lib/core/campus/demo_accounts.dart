import '../../models/campus/campus_user.dart';

/// 一个演示账号。登录页直接把这些显示出来，点一下自动填。
class DemoAccount {
  const DemoAccount({
    required this.studentId,
    required this.password,
    required this.name,
    required this.className,
    required this.role,
    required this.note,
  });

  final String studentId;
  final String password;
  final String name;
  final String className;
  final UserRole role;
  final String note;
}

/// 种子数据里预置的三个可登录账号，三档角色各一个。
/// 改这里必须同步改 `mock_seed.dart` 的 users，否则登录不上。
const List<DemoAccount> kDemoAccounts = [
  DemoAccount(
    studentId: '20250101',
    password: '123456',
    name: '张小明',
    className: '软件2615',
    role: UserRole.student,
    note: '学生视角：能发布、报名、接单，不能发活动/建表单',
  ),
  DemoAccount(
    studentId: '20250102',
    password: '123456',
    name: '李思远',
    className: '软件2615',
    role: UserRole.committeeman,
    note: '班委视角：可发活动（需审核）、建表单、看汇总',
  ),
  DemoAccount(
    studentId: '20250103',
    password: '123456',
    name: '王老师',
    className: '软件2615',
    role: UserRole.admin,
    note: '管理员视角：发活动直接通过、可删他人内容',
  ),
];
