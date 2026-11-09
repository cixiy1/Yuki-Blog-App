import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../models/campus/campus_scope.dart';
import '../../../../models/campus/express_task.dart';
import '../../shared/campus_format.dart';
import '../../shared/status_chip.dart';

/// 列表里的一条快递代取。
class ExpressCard extends StatelessWidget {
  const ExpressCard({super.key, required this.task, required this.onTap});

  final ExpressTask task;
  final VoidCallback onTap;

  Color _statusColor(ColorScheme scheme) => switch (task.status) {
        ExpressStatus.pending => scheme.primary,
        ExpressStatus.accepted => scheme.tertiary,
        ExpressStatus.delivered => scheme.secondary,
        ExpressStatus.completed => scheme.outline,
        ExpressStatus.cancelled => scheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final finished = task.status.isFinished;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
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
                  children: [
                    StatusChip(
                      label: task.status.label,
                      color: _statusColor(scheme),
                    ),
                    if (task.scope == VisibilityScope.classOnly) ...[
                      const SizedBox(width: AppTheme.spacingXs),
                      StatusChip(label: task.scope.label, color: scheme.outline),
                    ],
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        task.station,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: finished ? scheme.onSurfaceVariant : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatMoney(task.rewardCents),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: finished ? scheme.outline : scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '送到 ${task.deliverTo}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      task.isPickupCodeMasked
                          ? Icons.lock_outline
                          : Icons.qr_code_2_outlined,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      task.isPickupCodeMasked ? '取件码接单后可见' : task.pickupCode,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        finished
                            ? task.status.label
                            : formatDeadline(task.deadline),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.creatorName} · ${formatRelative(task.createdAt)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
