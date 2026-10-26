import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/course_cell.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

const _weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 表头行高。左侧行标列顶部留同样高度，首行行标才和表体首行齐平。
const _headerHeight = 28.0;

/// 表头与表体之间的缝隙。
const _headerGap = 2.0;

String weekdayLabel(int day) =>
    day >= 1 && day <= 7 ? _weekdayNames[day] : '周$day';

/// 课表网格：每天一列 + 行首/行尾内联的时段行标，整体在一个横向滚动视图里。
///
/// 行标内联在每行的行首（放不下时行尾再补一列），和课程格子一起滚动——
/// 行标跟着内容一起走，不再漂在滚动区之外。
/// - 一屏放得下时只留左侧行标；放不下时左右各一列（列宽按实际列数扣）；
/// - 列宽在 [SchedulePalette.cellMinWidth] ~ [SchedulePalette.cellMaxWidth]
///   之间自适应，窄屏横向滚动；
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
        // 一屏放得下（不必横向滚动）就只留左侧行标；放不下才在行尾再补一列。
        final fitsWithoutScroll =
            constraints.maxWidth >=
            SchedulePalette.labelWidth +
                dayCount * SchedulePalette.cellMinWidth;
        final labelColumns = fitsWithoutScroll ? 1 : 2;
        final available =
            constraints.maxWidth - SchedulePalette.labelWidth * labelColumns;
        final cellWidth =
            (available / dayCount)
                .clamp(SchedulePalette.cellMinWidth, SchedulePalette.cellMaxWidth)
                .toDouble();

        // 行高 = 该行最大堆叠格数 × 单格高度（含 2px 内边距），
        // 避免 ListView 无界高度把 stretch 约束撑爆。
        final rowHeights = schedule.rows.map((row) {
          final maxEntries = schedule.days
              .map((d) => schedule.entriesAt(d, row.key).length)
              .fold(1, (a, b) => a > b ? a : b);
          return maxEntries * (SchedulePalette.cellHeight + 4);
        }).toList(growable: false);

        final showTrailingLabel = !fitsWithoutScroll;
        final totalWidth =
            SchedulePalette.labelWidth * labelColumns +
            cellWidth * schedule.days.length;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                SizedBox(
                  height: _headerHeight,
                  child: _DayHeaderRow(
                    days: schedule.days,
                    weekMonday: weekMonday,
                    todayWeekday: todayWeekday,
                    cellWidth: cellWidth,
                    scheme: scheme,
                    showTrailingLabel: showTrailingLabel,
                  ),
                ),
                const SizedBox(height: _headerGap),
                for (var i = 0; i < schedule.rows.length; i++)
                  _GridRow(
                    row: schedule.rows[i],
                    height: rowHeights[i],
                    days: schedule.days,
                    cellWidth: cellWidth,
                    selectedKey: selectedKey,
                    onSelectEntry: onSelectEntry,
                    entriesAt: schedule.entriesAt,
                    showTrailingLabel: showTrailingLabel,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 表体的一行：行首行标 + 按天铺格子（放不下时行尾再补一个行标）。
/// 行标内联在行内，随内容一起横向滚动。
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.row,
    required this.height,
    required this.days,
    required this.cellWidth,
    required this.selectedKey,
    required this.onSelectEntry,
    required this.entriesAt,
    required this.showTrailingLabel,
  });

  final SlotRow row;
  final double height;
  final List<int> days;
  final double cellWidth;
  final String? selectedKey;
  final ValueChanged<ResolvedEntry> onSelectEntry;
  final List<ResolvedEntry> Function(int day, String rowKey) entriesAt;
  final bool showTrailingLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlotLabelCell(row: row),
          for (final day in days)
            _dayCell(day),
          if (showTrailingLabel) SlotLabelCell(row: row, alignEnd: true),
        ],
      ),
    );
  }

  Widget _dayCell(int day) {
    final entries = entriesAt(day, row.key);
    if (entries.isEmpty) {
      return SizedBox(width: cellWidth, child: const EmptyCourseCell());
    }
    // 解析器已按「本周实际 > 晚自习 > 非本周」保证一格一条，
    // 这里仍按列表渲染，留作多条的兜底（纵向堆叠）。
    return SizedBox(
      width: cellWidth,
      child: Column(
        children: entries.map((entry) {
          return CourseCell(
            key: ValueKey(entry.key),
            entry: entry,
            isSelected: entry.key == selectedKey,
            onTap: () => onSelectEntry(entry),
          );
        }).toList(),
      ),
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
    required this.showTrailingLabel,
  });

  final List<int> days;
  final DateTime weekMonday;
  final int todayWeekday;
  final double cellWidth;
  final ColorScheme scheme;
  final bool showTrailingLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: SchedulePalette.labelWidth),
        for (final day in days)
          SizedBox(
            width: cellWidth,
            child: Center(
              child: Builder(
                builder: (context) {
                  final date = weekMonday.add(Duration(days: day - 1));
                  final isToday = day == todayWeekday;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isToday ? scheme.primary : null,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    ),
                    child: Text(
                      '${weekdayLabel(day)} ${date.month}/${date.day}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isToday ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        if (showTrailingLabel)
          const SizedBox(width: SchedulePalette.labelWidth),
      ],
    );
  }
}
