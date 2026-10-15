import 'package:flutter/material.dart';
import 'package:myclass/app/theme.dart';
import 'package:myclass/core/timetable_resolver.dart';
import 'package:myclass/features/schedule/widgets/schedule_palette.dart';

/// 课程格子：短名 + 角标 + 教室 + 教师。
///
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.short,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: dimmed,
                        decoration: entry.status == CellStatus.cancel
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: dimmed,
                      ),
                    ),
                  ),
                  if (showFlag) ...[
                    const SizedBox(width: 3),
                    Text(
                      entry.flag,
                      style: TextStyle(fontSize: 9, color: dimmed),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              if (entry.room.isNotEmpty)
                Text(
                  entry.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: dimmed),
                ),
              if (entry.teacher.isNotEmpty)
                Text(
                  entry.teacher,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: dimmed),
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
