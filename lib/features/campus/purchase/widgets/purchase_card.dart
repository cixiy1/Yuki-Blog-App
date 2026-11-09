import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../models/campus/purchase_task.dart';
import '../../shared/campus_format.dart';
import '../../shared/status_chip.dart';

/// 列表里的一条代买 / 跑腿。
class PurchaseCard extends StatelessWidget {
  const PurchaseCard({super.key, required this.task, required this.onTap});

  final PurchaseTask task;
  final VoidCallback onTap;

  Color _statusColor(ColorScheme scheme) => switch (task.status) {
        PurchaseStatus.pending => scheme.primary,
        PurchaseStatus.accepted => scheme.tertiary,
        PurchaseStatus.delivered => scheme.secondary,
        PurchaseStatus.completed => scheme.outline,
        PurchaseStatus.cancelled => scheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final finished = task.status == PurchaseStatus.completed ||
        task.status == PurchaseStatus.cancelled;

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
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        task.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: finished ? scheme.onSurfaceVariant : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatMoney(task.amountCents),
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
                    Icon(Icons.trip_origin, size: 12, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        task.fromPlace,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_right_alt, size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        task.toPlace,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${task.items.length} 样东西',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    Text(
                      task.paymentMethod.label,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      finished ? task.status.label : formatDeadline(task.deadline),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
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
