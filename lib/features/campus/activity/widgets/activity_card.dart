import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../models/campus/campus_activity.dart';
import '../../../../models/campus/campus_scope.dart';
import '../../shared/campus_format.dart';
import '../../shared/status_chip.dart';

/// 活动卡片。信息流里的一行，点开是详情。
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity, required this.onTap});

  final CampusActivity activity;
  final VoidCallback onTap;

  Color _statusColor(ColorScheme scheme) => switch (activity.status) {
        ActivityStatus.approved => scheme.primary,
        ActivityStatus.pendingReview => scheme.tertiary,
        ActivityStatus.rejected => scheme.error,
        ActivityStatus.cancelled || ActivityStatus.finished => scheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = _statusColor(scheme);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    StatusChip(
                      label: activity.status.label,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),
                _iconLine(
                  context,
                  Icons.schedule_rounded,
                  '${formatDateTime(activity.startAt)} 起',
                ),
                const SizedBox(height: 4),
                _iconLine(
                  context,
                  Icons.place_outlined,
                  activity.location,
                ),
                const SizedBox(height: AppTheme.spacingSm),
                Wrap(
                  spacing: AppTheme.spacingXs,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(
                      label: activity.isFull
                          ? '已满 ${activity.confirmedCount}/${activity.capacity}'
                          : '${activity.confirmedCount}/${activity.capacity} 人',
                      color: activity.isFull ? scheme.error : scheme.primary,
                      icon: Icons.groups_outlined,
                    ),
                    if (activity.waitlistCount > 0)
                      StatusChip(
                        label: '候补 ${activity.waitlistCount} 人',
                        color: scheme.tertiary,
                      ),
                    if (activity.scope == VisibilityScope.schoolWide)
                      StatusChip(label: '全校', color: scheme.secondary),
                    if (activity.mySignup != null)
                      StatusChip(
                        label: activity.mySignup!.status ==
                                SignupStatus.confirmed
                            ? '已报名'
                            : '候补第 ${activity.mySignup!.queuePosition} 位',
                        color: activity.mySignup!.status ==
                                SignupStatus.confirmed
                            ? scheme.primary
                            : scheme.tertiary,
                        icon: Icons.person_outline,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Row(
                  children: [
                    Text(
                      activity.organizerName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Text(
                      activity.status == ActivityStatus.approved
                          ? formatDeadline(activity.signupDeadline)
                          : formatRelative(activity.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: activity.status == ActivityStatus.approved &&
                                activity.isFull
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconLine(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
