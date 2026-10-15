import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';

/// 周次工具条：上一周 / 周次选择 / 下一周 + 「回到本周」。
///
/// 按钮位置固定，不随周次标签宽度漂移；到边界周（第 1 / 最后一周）
/// 自动置灰，已在本周时「回到本周」置灰。
class WeekBar extends StatelessWidget {
  const WeekBar({
    super.key,
    required this.week,
    required this.totalWeeks,
    required this.currentWeek,
    required this.weekMonday,
    required this.weekSunday,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPickWeek,
  });

  final int week;
  final int totalWeeks;
  final int currentWeek;
  final DateTime weekMonday;
  final DateTime weekSunday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback onPickWeek;

  String get _dateRange =>
      '${weekMonday.month}/${weekMonday.day} – ${weekSunday.month}/${weekSunday.day}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = week == currentWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: week > 1 ? onPrev : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: '上一周',
              style: IconButton.styleFrom(
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onPickWeek,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '第 $week 周',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          // 「本周」徽章常驻占位，避免按钮位置随标签宽度漂移
                          Text(
                            '本周',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isCurrent
                                  ? scheme.onPrimary
                                  : Colors.transparent,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      Text(
                        _dateRange,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: week < totalWeeks ? onNext : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: '下一周',
              style: IconButton.styleFrom(
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
          ],
        ),
        if (!isCurrent)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onToday,
              icon: const Icon(Icons.today, size: 16),
              label: const Text('回到本周'),
            ),
          ),
      ],
    );
  }
}

/// 周次选择底部弹层。
Future<void> showWeekPicker(
  BuildContext context, {
  required int week,
  required int totalWeeks,
  required int currentWeek,
  required DateTime week1Monday,
  required ValueChanged<int> onPick,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择周次',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: AppTheme.spacingSm,
                    crossAxisSpacing: AppTheme.spacingSm,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: totalWeeks,
                  itemBuilder: (context, index) {
                    final w = index + 1;
                    final monday =
                        week1Monday.add(Duration(days: index * 7));
                    final selected = w == week;
                    final isCurrent = w == currentWeek;
                    return InkWell(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                      onTap: () {
                        onPick(w);
                        Navigator.pop(sheetContext);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected ? scheme.primary : null,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : isCurrent
                                    ? scheme.primary.withValues(alpha: 0.5)
                                    : scheme.outlineVariant,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '第 $w 周',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                              ),
                            ),
                            Text(
                              '${monday.month}/${monday.day}',
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? scheme.onPrimary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
