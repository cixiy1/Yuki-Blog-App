import 'package:flutter/material.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/schedule_palette.dart';

/// 图例：状态色块说明。
class TimetableLegend extends StatelessWidget {
  const TimetableLegend({super.key});

  static const _items = <(CellStatus, String)>[
    (CellStatus.on, '有课'),
    (CellStatus.off, '非本周'),
    (CellStatus.add, '新增'),
    (CellStatus.cancel, '停课'),
    (CellStatus.study, '晚自习'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: _items.map((item) {
        final (bg, fg) = SchedulePalette.statusColors(item.$1, scheme);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: fg.withValues(alpha: 0.35)),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.$2,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
