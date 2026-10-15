import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/models/timetable.dart';

/// 通知面板：与课表网格解耦，数据驱动。
///
/// 通知按「真实周次」过滤（不随浏览的周次变化），
/// 过期自动消失；多条全部展示。
class NoticesPanel extends StatelessWidget {
  const NoticesPanel({super.key, required this.notices});

  final List<TimetableNotice> notices;

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined,
                  size: 16, color: scheme.onTertiaryContainer),
              const SizedBox(width: 6),
              Text(
                '通知',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          ...notices.map((notice) => Padding(
                padding:
                    const EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: scheme.tertiary,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Text(
                            notice.date,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notice.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (notice.text.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notice.text,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
