import 'package:flutter/material.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';

/// 课表界面共用的配色与尺寸。
///
/// 状态色全部从 [ColorScheme] 派生，亮色 / 暗色自动适配：
/// - 有课 → primaryContainer（蓝）
/// - 非本周 → surfaceContainerHighest（灰，文字压暗）
/// - 新增 → tertiaryContainer（绿）
/// - 停课 → errorContainer（红）
/// - 晚自习 → secondaryContainer（蓝灰）
class SchedulePalette {
  SchedulePalette._();

  static (Color background, Color foreground) statusColors(
    CellStatus status,
    ColorScheme scheme,
  ) =>
      switch (status) {
        CellStatus.on => (scheme.primaryContainer, scheme.onPrimaryContainer),
        CellStatus.off => (
            scheme.surfaceContainerHighest,
            scheme.onSurfaceVariant
          ),
        CellStatus.add => (
            scheme.tertiaryContainer,
            scheme.onTertiaryContainer
          ),
        CellStatus.cancel => (scheme.errorContainer, scheme.onErrorContainer),
        CellStatus.study => (
            scheme.secondaryContainer,
            scheme.onSecondaryContainer
          ),
      };

  /// 「本周调整」类型小圆点颜色。
  static Color changeDotColor(String type, ColorScheme scheme) =>
      switch (type) {
        'room' || 'move' => scheme.primary,
        'cancel' => scheme.error,
        'add' => scheme.tertiary,
        'practice' => scheme.secondary,
        _ => scheme.outline,
      };

  static const double labelWidth = 58;
  static const double cellHeight = 66;
  static const double cellMinWidth = 98;
  static const double cellMaxWidth = 200;
}

/// 网格的时段行标（如 "1-2节 / 08:30–10:00"）。
///
/// 表格左右两端各放一列：横向滚动到中间时，两边都能对上节次与时间。
/// 右列传 [alignEnd]，文字右对齐，视觉上才像表格的行头。
class SlotLabelCell extends StatelessWidget {
  const SlotLabelCell({super.key, required this.row, this.alignEnd = false});

  final SlotRow row;

  /// 右列行标：文字右对齐。
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return SizedBox(
      width: SchedulePalette.labelWidth,
      child: Column(
        crossAxisAlignment: align,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.label,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: row.isCustom ? scheme.tertiary : scheme.onSurface,
            ),
          ),
          if (row.timeText.isNotEmpty)
            Text(
              row.timeText,
              maxLines: 2,
              textAlign: textAlign,
              style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
