import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/campus_user.dart';
import '../shared/role_badge.dart';

/// 校园服务门户。
///
/// 本节先落地身份条与模块入口；信息流在后续批次接上。
class CampusPortalPage extends StatefulWidget {
  const CampusPortalPage({super.key, this.services});

  final CampusServices? services;

  @override
  State<CampusPortalPage> createState() => _CampusPortalPageState();
}

class _CampusPortalPageState extends State<CampusPortalPage> {
  CampusServices get _services => widget.services ?? CampusServices.instance;

  @override
  Widget build(BuildContext context) {
    final user = _services.session.user;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        AppTheme.spacingXl,
      ),
      children: [
        if (user != null) _IdentityHeader(user: user),
        const SizedBox(height: AppTheme.spacingLg),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Column(
            children: [
              Icon(Icons.construction_rounded,
                  size: 32, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                '六大模块正在接入',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                '失物招领 · 二手闲置 · 快递代取 · 活动报名 · 表单收集 · 代买跑腿',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.user});

  final CampusUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        CircleAvatar(
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}
