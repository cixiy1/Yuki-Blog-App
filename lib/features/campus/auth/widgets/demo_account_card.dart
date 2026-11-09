import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/campus/demo_accounts.dart';
import '../../../../models/campus/campus_user.dart';

/// 演示账号速查卡。点一行就把学号密码填进表单。
///
/// 没有真后端的时候，不把账号明着摆出来等于没法用。
class DemoAccountCard extends StatelessWidget {
  const DemoAccountCard({
    super.key,
    required this.onPick,
    this.accounts = kDemoAccounts,
  });

  final void Function(DemoAccount account) onPick;
  final List<DemoAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingSm,
          AppTheme.spacingSm,
          AppTheme.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.vpn_key_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppTheme.spacingXs),
                Text(
                  '演示账号（点一下自动填入）',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXs),
            for (final account in accounts)
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                onTap: () => onPick(account),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      _RoleDot(role: account.role),
                      const SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  account.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingXs),
                                Text(
                                  '${account.studentId} / ${account.password}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              account.note,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 12, color: scheme.outline),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleDot extends StatelessWidget {
  const _RoleDot({required this.role});

  final UserRole role;

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
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        String.fromCharCode(role.label.runes.first),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
