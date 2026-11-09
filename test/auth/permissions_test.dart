import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/campus/permissions.dart';
import 'package:yuki_blog_app/models/campus/campus_user.dart';

void main() {
  test('未登录时任何能力都不开放', () {
    for (final capability in Capability.values) {
      expect(can(null, capability), isFalse, reason: capability.name);
    }
  });

  test('学生只能做参与类操作', () {
    for (final capability in Capability.values) {
      expect(can(UserRole.student, capability), isFalse,
          reason: '${capability.name} 不该给学生');
    }
  });

  test('班委能发活动 / 建表单 / 看汇总，但不能删他人内容', () {
    expect(can(UserRole.committeeman, Capability.createActivity), isTrue);
    expect(can(UserRole.committeeman, Capability.reviewActivity), isTrue);
    expect(can(UserRole.committeeman, Capability.createForm), isTrue);
    expect(can(UserRole.committeeman, Capability.viewFormSummary), isTrue);
    expect(can(UserRole.committeeman, Capability.viewSignupList), isTrue);
    expect(can(UserRole.committeeman, Capability.deleteAnyPost), isFalse);
    expect(can(UserRole.committeeman, Capability.resetDemoData), isFalse);
  });

  test('管理员在班委之上再多两项破坏性能力', () {
    for (final capability in Capability.values) {
      expect(can(UserRole.admin, capability), isTrue, reason: capability.name);
    }
  });
}
