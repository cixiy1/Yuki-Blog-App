import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../shared/empty_state.dart';
import '../../shared/section_header.dart';

/// 门户里的一段信息流：标题 + 「查看全部」 + 若干条精简卡。
///
/// 泛型只为让调用点少写一次 map，内部渲染交给 [itemBuilder]。
class FeedPreviewSection<T> extends StatelessWidget {
  const FeedPreviewSection({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.onViewAll,
    this.emptyText = '暂时还没有内容',
    this.emptyIcon = Icons.inbox_outlined,
  });

  final String title;
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onViewAll;
  final String emptyText;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          actionLabel: '查看全部',
          onAction: onViewAll,
          padding: const EdgeInsets.only(
            top: AppTheme.spacingLg,
            bottom: AppTheme.spacingSm,
          ),
        ),
        if (items.isEmpty)
          EmptyState(
            icon: emptyIcon,
            title: emptyText,
            compact: true,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: AppTheme.spacingMd),
                  itemBuilder(context, items[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
