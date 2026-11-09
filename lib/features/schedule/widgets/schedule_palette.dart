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

  /// 行标列宽：只放紧凑节次号（如 "1-2"），整周 7 列才铺得进手机竖屏。
  static const double labelWidth = 30;
  static const double cellHeight = 66;
}

/// 网格的时段行标（紧凑版）。
///
/// 一屏铺满整周后行标列只有 30px，标准行只显示节次号
/// （"1-2节" → "1-2"），时间段信息收进课程详情面板；
/// 自定义行（临时活动）额外带一行起始时间。纯文本，无底色无边框，
/// 直接压在页面背景上、靠留白和课程格子区分。
class SlotLabelCell extends StatelessWidget {
  const SlotLabelCell({super.key, required this.row});

  final SlotRow row;

  /// 标准行标剥掉「节」字：1-2节 → 1-2，11节 → 11。
  String get shortLabel =>
      row.label.endsWith('节') ? row.label.substring(0, row.label.length - 1) : row.label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: SchedulePalette.labelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            shortLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: row.isCustom ? scheme.tertiary : scheme.onSurface,
            ),
          ),
          if (row.isCustom && row.timeText.isNotEmpty)
            Text(
              row.timeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
