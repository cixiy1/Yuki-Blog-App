import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/keyword_highlight.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

/// 「本周调整」面板：换教室 / 停课 / 调课 / 新增 / 对调 / 提示 / 实践周。
///
/// 无调整时整块隐藏。正文只走「词表着色」——课程名、地点、动作按类别上色加划线，
/// 但**不铺句子底纹、不按档位加粗**：这里的文案是运行时用
/// `「课程名」+ 调整说明` 拼出来的，不是可标注的整段原文；而且每一行本身
/// 就是「这周要处理的事」，再叠一层档位底纹只会让列表变成一片花黄、看不出哪条是哪条。
class WeekChangesPanel extends StatelessWidget {
  const WeekChangesPanel({super.key, required this.changes});

  final List<ChangeItem> changes;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '本周调整',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Text(
                  '共 ${changes.length} 条',
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          ...changes.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: SchedulePalette.changeDotColor(
                              item.type, scheme),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: buildKeywordSpans(
                            item.text,
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
      ),
    );
  }
}
