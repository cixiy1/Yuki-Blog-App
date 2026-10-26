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
/// 节次加粗突出，时间用等宽数字单行自适应缩放（58px 里放得下 08:30–10:00）。
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
      height: SchedulePalette.cellHeight,
      child: Column(
        crossAxisAlignment: align,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.label,
            textAlign: textAlign,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: row.isCustom ? scheme.tertiary : scheme.onSurface,
            ),
          ),
          if (row.timeText.isNotEmpty) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                row.timeText,
                textAlign: textAlign,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  // 等宽数字：上下两行的时间才能对齐成一条竖线
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
