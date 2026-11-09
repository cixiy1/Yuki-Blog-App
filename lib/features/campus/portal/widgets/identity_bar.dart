import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../models/campus/campus_user.dart';
import '../../shared/role_badge.dart';

/// 门户顶部的身份条：头像 + 姓名 + 角色 + 班级/信用 + 消息入口。
class IdentityBar extends StatelessWidget {
  const IdentityBar({
    super.key,
    required this.user,
    required this.unread,
    this.onTapMessages,
    this.onTapProfile,
  });

  final CampusUser user;
  final int unread;
  final VoidCallback? onTapMessages;
  final VoidCallback? onTapProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTapProfile,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              user.avatarLetter,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  RoleBadge(role: user.role),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${user.className} · 信用 ${user.creditScore}（${user.creditTier.label}）',
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onTapMessages,
          tooltip: '消息中心',
          icon: Badge.count(
            count: unread,
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }
}
