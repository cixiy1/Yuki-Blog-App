import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../models/campus/app_message.dart';
import '../../shared/campus_format.dart';

/// 收件箱里的一行。未读时左侧有个小圆点。
class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.message,
    required this.onTap,
  });

  final AppMessage message;
  final VoidCallback onTap;

  IconData get _icon => switch (message.type) {
        MessageType.activityApproved => Icons.check_circle_outline,
        MessageType.activityPendingReview => Icons.fact_check_outlined,
        MessageType.activityRejected => Icons.cancel_outlined,
        MessageType.activityPromoted => Icons.upgrade_rounded,
        MessageType.activityCancelled => Icons.event_busy_outlined,
        MessageType.expressAccepted => Icons.inventory_2_outlined,
        MessageType.expressDelivered => Icons.local_shipping_outlined,
        MessageType.purchaseAccepted => Icons.delivery_dining_outlined,
        MessageType.purchaseCompleted => Icons.task_alt_rounded,
        MessageType.formReminder => Icons.assignment_outlined,
        MessageType.creditChanged => Icons.star_outline_rounded,
      };

  Color _color(ColorScheme scheme) => switch (message.type) {
        MessageType.activityRejected ||
        MessageType.activityCancelled =>
          scheme.error,
        MessageType.creditChanged => scheme.tertiary,
        _ => scheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = !message.read;
    final color = _color(scheme);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(_icon, size: 18, color: color),
                ),
                if (unread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      Text(
                        formatRelative(message.createdAt),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.body,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
