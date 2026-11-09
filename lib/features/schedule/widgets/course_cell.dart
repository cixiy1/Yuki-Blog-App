import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

/// 课程格子：短名 + 角标 + 教室 + 教师（紧凑版，整周一屏布局）。
///
/// 列宽在手机上只有 ~48px，所以课名允许多行换行、字号整体缩小；
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
          height: SchedulePalette.cellHeight,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: isSelected
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 课名占满剩余空间（最多 4 行），空间不够时先压课名，
              // 保证教室/教师这两行关键信息始终可见。
              Flexible(
                child: Text(
                  entry.short,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: dimmed,
                    decoration: entry.status == CellStatus.cancel
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: dimmed,
                  ),
                ),
              ),
              if (showFlag)
                Text(
                  entry.flag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8, color: dimmed),
                ),
              if (entry.room.isNotEmpty || entry.teacher.isNotEmpty)
                const Spacer(),
              if (entry.room.isNotEmpty)
                Text(
                  entry.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: dimmed),
                ),
              if (entry.teacher.isNotEmpty)
                Text(
                  entry.teacher,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8.5, color: dimmed),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空格子：极淡的占位底，不描边。
class EmptyCourseCell extends StatelessWidget {
  const EmptyCourseCell({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        height: SchedulePalette.cellHeight,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }
}
