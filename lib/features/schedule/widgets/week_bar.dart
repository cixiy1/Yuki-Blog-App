import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

/// 周次工具条：上一周 / 周次选择 / 下一周 + 「回到本周」。
///
/// 窄屏：左右箭头夹居中周次标签（两行），「回到本周」在下方单独一行；
/// 宽屏（≥ [SchedulePalette.wideBreakpoint]）对齐网页版 .tt-bar：
/// 单行内联——上一周 / 第 N 周 + 日期范围 / 下一周 / 回到本周，
/// 「回到本周」常驻（本周时置灰，对齐网页 .tt-now 的占位策略）。
/// 按钮位置固定，不随周次标签宽度漂移；到边界周（第 1 / 最后一周）
/// 自动置灰。
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
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >=
              SchedulePalette.wideBreakpoint
          ? _buildWide(context)
          : _buildCompact(context),
    );
  }

  /// 宽屏：单行内联，对齐网页版 .tt-bar。
  ///
  /// 主题给 OutlinedButton 设了 `minimumSize: Size.fromHeight(48)`
  /// （宽度无穷大 → 通栏表单按钮），这里必须覆盖成内容宽，
  /// 否则 Wrap 里每个按钮各占一行。
  Widget _buildWide(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrent = week == currentWeek;
    final chipStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: const TextStyle(fontSize: 13),
    );
    return Wrap(
      spacing: AppTheme.spacingSm,
      runSpacing: AppTheme.spacingXs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: week > 1 ? onPrev : null,
          style: chipStyle,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('上一周'),
        ),
        InkWell(
          onTap: onPickWeek,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '第 $week 周',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _dateRange,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                // 「本周」徽章常驻占位，宽度不随出现/消失抖动。
                Text(
                  '本周',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? scheme.onPrimary : Colors.transparent,
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
          ),
        ),
        OutlinedButton(
          onPressed: week < totalWeeks ? onNext : null,
          style: chipStyle,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('下一周'),
              Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
        // 常驻（本周置灰）：网页 .tt-now 的占位策略，按钮不跳位。
        OutlinedButton(
          onPressed: isCurrent ? null : onToday,
          style: chipStyle,
          child: const Text('回到本周'),
        ),
      ],
    );
  }

  /// 窄屏：左右箭头 + 居中周次标签，「回到本周」单独一行。
  Widget _buildCompact(BuildContext context) {
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
        // 「回到本周」常驻占位（网页 .tt-now is-hidden 的 visibility 策略）：
        // 在本周时只隐藏不撤行，翻周瞬间布局不跳动。
        Visibility(
          visible: !isCurrent,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: isCurrent ? null : onToday,
              icon: const Icon(Icons.today, size: 16),
              label: const Text('回到本周'),
            ),
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
