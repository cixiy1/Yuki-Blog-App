import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/campus/media_repository.dart';
import '../../../../models/campus/lost_found_post.dart';
import '../../shared/campus_format.dart';
import '../../shared/campus_image.dart';
import '../../shared/status_chip.dart';

/// 列表里的一条失物招领。
class LostFoundCard extends StatelessWidget {
  const LostFoundCard({
    super.key,
    required this.post,
    required this.media,
    required this.onTap,
  });

  final LostFoundPost post;
  final MediaRepository media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLost = post.type == LostFoundType.lost;
    final cover = post.imageIds.isEmpty ? null : post.imageIds.first;

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
                  CampusImage(
                    imageId: cover,
                    media: media,
                    width: 64,
                    height: 64,
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusChip(
                            label: post.type.label,
                            color: isLost ? scheme.error : scheme.primary,
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: Text(
                              post.title,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 12, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              post.location,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          Text(
                            formatRelative(post.createdAt),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                          if (post.imageIds.length > 1) ...[
                            const SizedBox(width: AppTheme.spacingSm),
                            Icon(Icons.photo_library_outlined,
                                size: 11, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 2),
                            Text(
                              '${post.imageIds.length}',
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
