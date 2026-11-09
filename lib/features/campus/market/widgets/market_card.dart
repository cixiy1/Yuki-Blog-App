import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/campus/media_repository.dart';
import '../../../../models/campus/market_item.dart';
import '../../shared/campus_format.dart';
import '../../shared/campus_image.dart';
import '../../shared/status_chip.dart';

/// 列表里的一件二手物品。
class MarketCard extends StatelessWidget {
  const MarketCard({
    super.key,
    required this.item,
    required this.media,
    required this.onTap,
  });

  final MarketItem item;
  final MediaRepository media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cover = item.imageIds.isEmpty ? null : item.imageIds.first;
    final sold = !item.isOnSale;

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cover != null) ...[
                  Opacity(
                    opacity: sold ? 0.45 : 1,
                    child: CampusImage(
                      imageId: cover,
                      media: media,
                      width: 76,
                      height: 76,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: sold ? scheme.onSurfaceVariant : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatMoney(item.priceCents),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: sold ? scheme.outline : scheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          if (sold)
                            StatusChip(label: item.status.label, color: scheme.outline)
                          else
                            StatusChip(
                              label: item.condition.label,
                              color: scheme.tertiary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            item.category.label,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          Text(
                            formatRelative(item.createdAt),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                          const Spacer(),
                          if (item.imageIds.length > 1) ...[
                            Icon(Icons.photo_library_outlined,
                                size: 11, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Text(
                              '${item.imageIds.length}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
