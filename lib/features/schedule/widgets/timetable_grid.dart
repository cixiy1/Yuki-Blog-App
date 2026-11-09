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
const _headerHeight = 36.0;

/// 表头与表体之间的缝隙。
const _headerGap = 2.0;

/// 课表网格：整周一屏铺满，不做横向滚动。
///
/// - 只渲染**本周有课的星期列**（[WeekSchedule.days]），没课的整天不显示，
///   剩下的列用 [Expanded] 平分宽度——列数越少每列越宽；
/// - 行高由内容决定（[IntrinsicHeight]）：文字放不下的卡片会把整行撑高，
///   行标列随之拉伸对齐；
/// - 左侧行标列显示节次号 + 时间段（如 "1-2 / 08:30–10:00"）；
/// - 今天列在表头高亮（primary 底色胶囊）；
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
    // 只保留本周有课的列；全周无课时列数为 0（页面会另显示无课横幅）。
    final days = schedule.days;

    return Column(
      children: [
        if (days.isNotEmpty) ...[
          SizedBox(
            height: _headerHeight,
            child: _DayHeaderRow(
              days: days,
              weekMonday: weekMonday,
              todayWeekday: todayWeekday,
            ),
          ),
          const SizedBox(height: _headerGap),
        ],
        for (final row in schedule.rows)
          _GridRow(
            row: row,
            days: days,
            selectedKey: selectedKey,
            onSelectEntry: onSelectEntry,
            entriesAt: schedule.entriesAt,
          ),
      ],
    );
  }
}

/// 表体的一行：行首紧凑行标 + 有课的星期等宽列。
///
/// 用 [IntrinsicHeight] 让行高 = 行内最高格子的实际高度：
/// 课名长、换行多的卡片把整行撑高，而不是把文字截断。
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.row,
    required this.days,
    required this.selectedKey,
    required this.onSelectEntry,
    required this.entriesAt,
  });

  final SlotRow row;
  final List<int> days;
  final String? selectedKey;
  final ValueChanged<ResolvedEntry> onSelectEntry;
  final List<ResolvedEntry> Function(int day, String rowKey) entriesAt;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
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
/// 今天列用 primary 底色胶囊高亮。只渲染有课的列。
class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({
    required this.days,
    required this.weekMonday,
    required this.todayWeekday,
  });

  final List<int> days;
  final DateTime weekMonday;
  final int todayWeekday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const SizedBox(width: SchedulePalette.labelWidth),
        for (final day in days)
          Expanded(
            child: Center(
              child: Builder(
                builder: (context) {
                  final date = weekMonday.add(Duration(days: day - 1));
                  final isToday = day == todayWeekday;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
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
                            fontSize: 12.5,
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
                            fontSize: 10.5,
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
