import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/course_cell.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

const _weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayLabel(int day) =>
    day >= 1 && day <= 7 ? _weekdayNames[day] : '周$day';

/// 课表网格：左侧时段行标 + 每天一列，横向可滚动。
///
/// - 列宽按可用宽度在 [SchedulePalette.cellMinWidth] ~
///   [SchedulePalette.cellMaxWidth] 之间自适应，窄屏横向滚动；
/// - 今天列在表头高亮（primary 底色胶囊 + 「今天」）；
/// - 自定义时段行（临时活动）行标用 tertiary 色区分。
class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.schedule,
    required this.weekMonday,
    required this.todayWeekday,
    required this.selectedKey,
    required this.onSelectEntry,
  });

  final WeekSchedule schedule;

  /// 本周周一日期（用于表头显示 "M/d"）。
  final DateTime weekMonday;

  /// 今天的星期（1-7）；不在本周时为 -1。
  final int todayWeekday;

  /// 当前选中条目 key。
  final String? selectedKey;

  final ValueChanged<ResolvedEntry> onSelectEntry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayCount = schedule.days.isEmpty ? 1 : schedule.days.length;
        final available =
            constraints.maxWidth - SchedulePalette.labelWidth;
        final cellWidth =
            (available / dayCount).clamp(
              SchedulePalette.cellMinWidth,
              SchedulePalette.cellMaxWidth,
            ).toDouble();

        final totalWidth =
            SchedulePalette.labelWidth + cellWidth * schedule.days.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                _DayHeaderRow(
                  days: schedule.days,
                  weekMonday: weekMonday,
                  todayWeekday: todayWeekday,
                  cellWidth: cellWidth,
                  scheme: scheme,
                ),
                const SizedBox(height: 2),
                ...schedule.rows.map((row) {
                  // 行高 = 该行最大堆叠格数 × 单格高度（含 2px 内边距），
                  // 避免 ListView 无界高度把 stretch 约束撑爆
                  final maxEntries = schedule.days
                      .map((d) => schedule.entriesAt(d, row.key).length)
                      .fold(1, (a, b) => a > b ? a : b);
                  return SizedBox(
                    height: maxEntries *
                        (SchedulePalette.cellHeight + 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SlotLabelCell(row: row),
                        ...schedule.days.map((day) {
                          final entries = schedule.entriesAt(day, row.key);
                          if (entries.isEmpty) {
                            return SizedBox(
                              width: cellWidth,
                              child: const EmptyCourseCell(),
                            );
                          }
                          // 解析器已按「本周实际 > 晚自习 > 非本周」保证一格一条，
                          // 这里仍按列表渲染，留作多条的兜底（纵向堆叠）。
                          return SizedBox(
                            width: cellWidth,
                            child: Column(
                              children: entries.map((entry) {
                                final selected = entry.key == selectedKey;
                                return CourseCell(
                                  key: ValueKey(entry.key),
                                  entry: entry,
                                  isSelected: selected,
                                  onTap: () => onSelectEntry(entry),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({
    required this.days,
    required this.weekMonday,
    required this.todayWeekday,
    required this.cellWidth,
    required this.scheme,
  });

  final List<int> days;
  final DateTime weekMonday;
  final int todayWeekday;
  final double cellWidth;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: SchedulePalette.labelWidth),
        ...days.map((day) {
          final date = weekMonday.add(Duration(days: day - 1));
          final isToday = day == todayWeekday;
          return SizedBox(
            width: cellWidth,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isToday ? scheme.primary : null,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Text(
                  '${weekdayLabel(day)} ${date.month}/${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isToday ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
