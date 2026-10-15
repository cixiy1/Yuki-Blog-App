import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/keyword_highlight.dart';

/// 课程详情面板：点击格子后展开，再点同格或按 × 收起。
///
/// 底部的调整说明是「一段话」级别的长内容，同样走高亮——只做词表着色
/// （课程名 / 地点 / 动作按类别上色加划线），不铺底纹也不按档位加粗，
/// 与「本周调整」面板同一口径：这里是运行时拼出来的说明，不是可标注的原文。
class CourseDetailPanel extends StatelessWidget {
  const CourseDetailPanel({
    super.key,
    required this.entry,
    required this.onClose,
  });

  final ResolvedEntry entry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final infoRows = <({IconData icon, String label, String value})>[
      if (entry.teacher.isNotEmpty)
        (icon: Icons.person_outline, label: '教师', value: entry.teacher),
      if (entry.room.isNotEmpty)
        (
          icon: Icons.place_outlined,
          label: '地点',
          value: entry.roomDisplay
        ),
      if (entry.timeText.isNotEmpty)
        (icon: Icons.schedule_outlined, label: '时间', value: entry.timeText),
      if (entry.weeks.isNotEmpty)
        (
          icon: Icons.date_range_outlined,
          label: '周次',
          value: formatWeeks(entry.weeks)
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  entry.status.label,
                  style: TextStyle(fontSize: 11, color: scheme.onPrimary),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  entry.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
                tooltip: '收起',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          ...infoRows.map((row) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(row.icon, size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 40,
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        row.value,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          if (entry.changes.isNotEmpty) ...[
            const Divider(height: 20),
            ...entry.changes.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('· ',
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.onSurfaceVariant)),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: buildKeywordSpans(
                              note,
                              TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: scheme.onSurfaceVariant,
                              ),
                              isDark,
                              tiered: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
