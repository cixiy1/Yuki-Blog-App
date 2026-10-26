import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/course_cell.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

const _weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 表头行高。左右行标列顶部留同样的高度，第一行的行标才和表体首行齐平。
const _headerHeight = 28.0;

/// 表头与表体之间的缝隙。
const _headerGap = 2.0;

String weekdayLabel(int day) =>
    day >= 1 && day <= 7 ? _weekdayNames[day] : '周$day';

/// 课表网格：**左右两侧各一列时段行标** + 中间按天分列、横向滚动。
///
/// - 两列行标是固定的，只有表体横向滚动：滚到周三、周五时，左边和右边
///   都还能看到「第几节 / 几点到几点」，不用滚回去核对；
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
        // 只有「一屏就放得下、不用横向滚动」时才省掉右侧行标：
        // 放得下就说明节次始终看得见，右边再来一列纯属占地；
        // 放不下则必须留，否则滚到周三以后就没有节次可对照了。
        final fitsWithoutScroll =
            constraints.maxWidth >=
            SchedulePalette.labelWidth +
                dayCount * SchedulePalette.cellMinWidth;
        final labelColumns = fitsWithoutScroll ? 1 : 2;
        final available =
            constraints.maxWidth - SchedulePalette.labelWidth * labelColumns;
        final cellWidth =
            (available / dayCount).clamp(
              SchedulePalette.cellMinWidth,
              SchedulePalette.cellMaxWidth,
            ).toDouble();

        // 行高 = 该行最大堆叠格数 × 单格高度（含 2px 内边距），
        // 避免 ListView 无界高度把 stretch 约束撑爆。
        final rowHeights = schedule.rows.map((row) {
          final maxEntries = schedule.days
              .map((d) => schedule.entriesAt(d, row.key).length)
              .fold(1, (a, b) => a > b ? a : b);
          return maxEntries * (SchedulePalette.cellHeight + 4);
        }).toList(growable: false);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SlotLabelColumn(rows: schedule.rows, heights: rowHeights),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: cellWidth * schedule.days.length,
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
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!fitsWithoutScroll)
              _SlotLabelColumn(
                rows: schedule.rows,
                heights: rowHeights,
                alignEnd: true,
              ),
          ],
        );
      },
    );
  }
}

/// 固定的行标列（左 / 右各一）。顶部空出表头高度，与表体逐行对齐。
///
/// 没有任何底色或边框——时段行标直接压在页面背景上，和课程格子靠留白区分。
class _SlotLabelColumn extends StatelessWidget {
  const _SlotLabelColumn({
    required this.rows,
    required this.heights,
    this.alignEnd = false,
  });

  final List<SlotRow> rows;
  final List<double> heights;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    // 必须给出确定宽度：Row 的非 flex 子拿到的是 0..infinity 的松约束，
    // 直接 stretch 会把无限宽度传给子节点（BoxConstraints forces an
    // infinite width）。行标宽度本来就是固定的 labelWidth。
    return SizedBox(
      width: SchedulePalette.labelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: _headerHeight + _headerGap),
          for (var i = 0; i < rows.length; i++)
            SizedBox(
              height: heights[i],
              child: SlotLabelCell(row: rows[i], alignEnd: alignEnd),
            ),
        ],
      ),
    );
  }
}

/// 表体的一行：按天铺格子。
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.row,
    required this.height,
    required this.days,
    required this.cellWidth,
    required this.selectedKey,
    required this.onSelectEntry,
    required this.entriesAt,
  });

  final SlotRow row;
  final double height;
  final List<int> days;
  final double cellWidth;
  final String? selectedKey;
  final ValueChanged<ResolvedEntry> onSelectEntry;
  final List<ResolvedEntry> Function(int day, String rowKey) entriesAt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: days.map((day) {
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
  });

  final List<int> days;
  final DateTime weekMonday;
  final int todayWeekday;
  final double cellWidth;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: days.map((day) {
        final date = weekMonday.add(Duration(days: day - 1));
        final isToday = day == todayWeekday;
        return SizedBox(
          width: cellWidth,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            ),
          ),
        );
      }).toList(),
    );
  }
}
