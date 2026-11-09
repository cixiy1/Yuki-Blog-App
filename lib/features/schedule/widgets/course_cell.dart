import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

/// 课程格子：短名 + 角标 + 教室 + 教师。
///
/// 高度自适应：内容（换行后的课名/角标）超过 [SchedulePalette.cellHeight]
/// 时卡片向下撑高，网格级 IntrinsicHeight 取最高卡片的高度分给所有行，
/// 全局卡片尺寸统一；
/// 配色按状态从主题派生；停课课程名加删除线；
/// 选中态加 primary 描边（交互反馈）。
class CourseCell extends StatelessWidget {
  const CourseCell({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  final ResolvedEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = SchedulePalette.statusColors(entry.status, scheme);
    final dimmed = fg.withValues(alpha: entry.status == CellStatus.off ? 0.55 : 0.8);
    final showFlag = entry.flag.isNotEmpty && entry.flag != entry.short;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          // minHeight 兜底，内容多时自然向下撑开。
          constraints: BoxConstraints(
            minHeight: SchedulePalette.cellHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: isSelected
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 课名最多 4 行；行高自适应后无需 Flexible 压缩
              // （flex 子项在 IntrinsicHeight 的无界 dry layout 里会断言）。
              Text(
                entry.short,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: dimmed,
                  decoration: entry.status == CellStatus.cancel
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: dimmed,
                ),
              ),
              if (showFlag)
                Text(
                  entry.flag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: dimmed),
                ),
              // 不用 Spacer：行高由 IntrinsicHeight 的 dry layout 决定，
              // 该过程高度无界，flex 子项（Spacer/Expanded）会直接断言。
              if (entry.room.isNotEmpty && (entry.short.isNotEmpty || showFlag))
                const SizedBox(height: 3),
              if (entry.room.isNotEmpty)
                Text(
                  entry.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: dimmed),
                ),
              if (entry.teacher.isNotEmpty)
                Text(
                  entry.teacher,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5, color: dimmed),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空格子：极淡的占位底，不描边，最小高度与课程格子对齐。
class EmptyCourseCell extends StatelessWidget {
  const EmptyCourseCell({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        constraints: BoxConstraints(
          minHeight: SchedulePalette.cellHeight,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }
}
