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
/// - **所有行等高**：整个表体包一层 [IntrinsicHeight]、每行 [Expanded]——
///   flex 的 intrinsic 算法取「最高一行 × 行数」为总高，每行分到的高度
///   恰好等于最高行的需求，卡片尺寸全局统一且不截断内容；
/// - 左侧行标列显示节次号 + 时间段（如 "1-2 / 08:30–10:00"，宽屏带「节」）；
/// - 宽屏（≥ [SchedulePalette.wideBreakpoint]）对齐网页版：表头全名
///   「周一」居中、今天列 primary 着色文字、卡片字号/间距放大；
/// - 窄屏今天列在表头高亮（primary 底色胶囊）；
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
    // 宽屏对齐网页版：表头全名「周一」、今天着色文字、行标带「节」。
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= SchedulePalette.wideBreakpoint;
        return Column(
          children: [
            if (days.isNotEmpty) ...[
              SizedBox(
                height: _headerHeight,
                child: _DayHeaderRow(
                  days: days,
                  weekMonday: weekMonday,
                  todayWeekday: todayWeekday,
                  wide: wide,
                ),
              ),
              const SizedBox(height: _headerGap),
            ],
            // 表体整体包 IntrinsicHeight：所有行等高（= 最高行的需求高度），
            // 卡片尺寸全局统一。行内格子不能再出现 flex 子项——IntrinsicHeight
            // 的 dry layout 高度无界（见 _GridRow 注释）。
            IntrinsicHeight(
              child: Column(
                children: [
                  for (final row in schedule.rows)
                    Expanded(
                      child: _GridRow(
                        row: row,
                        days: days,
                        wide: wide,
                        selectedKey: selectedKey,
                        onSelectEntry: onSelectEntry,
                        entriesAt: schedule.entriesAt,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 表体的一行：行首紧凑行标 + 有课的星期等宽列。
///
/// 行高由外层统一分配（所有行等高）；本行内部用
/// `crossAxisAlignment: stretch` 让格子拉满行高。
/// **格子内禁止 flex 子项**（Spacer/Expanded/Flexible）：外层
/// IntrinsicHeight 走 intrinsic 查询时会对本 Row 做 dry layout，
/// 该过程高度无界，flex 子项会直接断言。
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.row,
    required this.days,
    required this.wide,
    required this.selectedKey,
    required this.onSelectEntry,
    required this.entriesAt,
  });

  final SlotRow row;
  final List<int> days;
  final bool wide;
  final String? selectedKey;
  final ValueChanged<ResolvedEntry> onSelectEntry;
  final List<ResolvedEntry> Function(int day, String rowKey) entriesAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlotLabelCell(row: row, wide: wide),
        for (final day in days) _dayCell(day),
      ],
    );
  }

  /// 每天的格子。返回值必须是 Row 的直接 flex 子项（Expanded）——
  /// stretch 把行高以**紧约束**传下去，单条目卡片才会填满整行，
  /// 全局卡片高度才真正一致（松约束下卡片会按内容收缩，各行参差）。
  Widget _dayCell(int day) {
    final entries = entriesAt(day, row.key);
    if (entries.isEmpty) {
      return const Expanded(child: EmptyCourseCell());
    }
    if (entries.length == 1) {
      final entry = entries.single;
      return Expanded(
        child: CourseCell(
          key: ValueKey(entry.key),
          entry: entry,
          wide: wide,
          isSelected: entry.key == selectedKey,
          onTap: () => onSelectEntry(entry),
        ),
      );
    }
    // 解析器已按「本周实际 > 晚自习 > 非本周」保证一格一条，
    // 多条只作兜底：纵向堆叠，卡片按内容收缩。
    return Expanded(
      child: Column(
        children: [
          for (final entry in entries)
            CourseCell(
              key: ValueKey(entry.key),
              entry: entry,
              wide: wide,
              isSelected: entry.key == selectedKey,
              onTap: () => onSelectEntry(entry),
            ),
        ],
      ),
    );
  }
}

/// 表头行：窄屏两行短星期名（"一"）+ 日期（"11/9"），今天列 primary 胶囊；
/// 宽屏对齐网页版：全名（"周一"）+ 日期居中，今天列用 primary 着色文字
/// （网页 .tt-dh.is-today，无底色）。
class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow({
    required this.days,
    required this.weekMonday,
    required this.todayWeekday,
    required this.wide,
  });

  final List<int> days;
  final DateTime weekMonday;
  final int todayWeekday;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(width: wide ? SchedulePalette.labelWidthWide : SchedulePalette.labelWidth),
        for (final day in days)
          Expanded(
            child: Center(
              child: Builder(
                builder: (context) {
                  final date = weekMonday.add(Duration(days: day - 1));
                  final isToday = day == todayWeekday;
                  final todayColor = scheme.primary;
                  if (wide) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _weekdayNames[day],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            fontWeight:
                                isToday ? FontWeight.w600 : FontWeight.w500,
                            color:
                                isToday ? todayColor : scheme.onSurface,
                          ),
                        ),
                        Text(
                          '${date.month}/${date.day}',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.2,
                            color: isToday
                                ? todayColor
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  }
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
