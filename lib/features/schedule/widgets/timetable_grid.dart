import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/course_cell.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

const _weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 表头短星期名（紧凑单字），下标 = 星期几 - 1。
const weekdayShortNames = ['一', '二', '三', '四', '五', '六', '日'];

String weekdayLabel(int day) =>
    day >= 1 && day <= 7 ? _weekdayNames[day] : '周$day';

/// 表头行高。左侧行标列顶部留同样高度，首行行标才和表体首行齐平。
const _headerHeight = 32.0;

/// 表头与表体之间的缝隙。
const _headerGap = 2.0;

/// 课表网格：整周一屏铺满，不做横向滚动。
///
/// - 固定渲染周一到周日 7 列，列宽用 [Expanded] 平分剩余宽度，
///   手机竖屏也能一页看完整周（参照主流课表 App 的紧凑网格）；
/// - 左侧行标列只留紧凑节次号（如 "1-2"），宽度 [SchedulePalette.labelWidth]；
/// - 今天列在表头高亮（primary 底色胶囊）；
/// - 自定义时段行（临时活动）行标用 tertiary 色区分；
/// - 左右滑动翻周由外层（课程表页）的手势负责，网格只管渲染。
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
    // 整周固定 7 列：周末没课也留空列，「一周」的语义完整，列宽也稳定。
    final days = List<int>.generate(7, (i) => i + 1);

    // 行高 = 该行最大堆叠格数 × 单格高度（含 2px 内边距），
    // 避免 ListView 无界高度把 stretch 约束撑爆。
    final rowHeights = schedule.rows.map((row) {
      final maxEntries = days
          .map((d) => schedule.entriesAt(d, row.key).length)
          .fold(1, (a, b) => a > b ? a : b);
      return maxEntries * (SchedulePalette.cellHeight + 4);
    }).toList(growable: false);

    return Column(
      children: [
        SizedBox(
          height: _headerHeight,
          child: _DayHeaderRow(
            weekMonday: weekMonday,
            todayWeekday: todayWeekday,
          ),
        ),
        const SizedBox(height: _headerGap),
        for (var i = 0; i < schedule.rows.length; i++)
          _GridRow(
            row: schedule.rows[i],
            height: rowHeights[i],
            days: days,
            selectedKey: selectedKey,
            onSelectEntry: onSelectEntry,
            entriesAt: schedule.entriesAt,
          ),
      ],
    );
  }
}

/// 表体的一行：行首紧凑行标 + 7 天等宽列。
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.row,
    required this.height,
    required this.days,
    required this.selectedKey,
    required this.onSelectEntry,
    required this.entriesAt,
  });

  final SlotRow row;
  final double height;
  final List<int> days;
  final String? selectedKey;
  final ValueChanged<ResolvedEntry> onSelectEntry;
  final List<ResolvedEntry> Function(int day, String rowKey) entriesAt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlotLabelCell(row: row),
          for (final day in days)
            Expanded(child: _dayCell(day)),
        ],
      ),
    );
  }

  Widget _dayCell(int day) {
    final entries = entriesAt(day, row.key);
    if (entries.isEmpty) {
      return const EmptyCourseCell();
    }
    // 解析器已按「本周实际 > 晚自习 > 非本周」保证一格一条，
    // 这里仍按列表渲染，留作多条的兜底（纵向堆叠）。
    return Column(
      children: entries.map((entry) {
        return CourseCell(
          key: ValueKey(entry.key),
          entry: entry,
          isSelected: entry.key == selectedKey,
          onTap: () => onSelectEntry(entry),
        );
      }).toList(),
    );
  }
}

/// 表头行：每列两行——短星期名（"一"）+ 日期（"11/9"）。
/// 今天列用 primary 底色胶囊高亮。
class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({
    required this.weekMonday,
    required this.todayWeekday,
  });

  final DateTime weekMonday;
  final int todayWeekday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const SizedBox(width: SchedulePalette.labelWidth),
        for (var day = 1; day <= 7; day++)
          Expanded(
            child: Center(
              child: Builder(
                builder: (context) {
                  final date = weekMonday.add(Duration(days: day - 1));
                  final isToday = day == todayWeekday;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isToday ? scheme.primary : null,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdayShortNames[day - 1],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: isToday
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                        ),
                        Text(
                          '${date.month}/${date.day}',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9,
                            height: 1.15,
                            color: isToday
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
