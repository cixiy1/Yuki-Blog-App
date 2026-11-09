import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../models/campus/campus_user.dart';

/// 学生 / 班委 / 管理员的小徽标。
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, this.dense = true});

  final UserRole role;
  final bool dense;

  Color _color(ColorScheme scheme) => switch (role) {
        UserRole.student => scheme.primary,
        UserRole.committeeman => scheme.tertiary,
        UserRole.admin => scheme.error,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: dense ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
