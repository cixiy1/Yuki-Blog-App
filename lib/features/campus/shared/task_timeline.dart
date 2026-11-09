import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'campus_format.dart';

/// 流程里的一步。
class TaskStep {
  const TaskStep({required this.label, this.at});

  final String label;

  /// 发生时间；为空表示还没走到这一步。
  final DateTime? at;

  bool get isDone => at != null;
}

/// 任务进度条：待接单 → 已接单 → 已送达 → 已完成。
///
/// 快递代取和代买跑腿共用一套流程，所以共用这个组件。
class TaskTimeline extends StatelessWidget {
  const TaskTimeline({super.key, required this.steps});

  final List<TaskStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: steps[i].isDone ? scheme.primary : scheme.outlineVariant,
                      ),
                    ),
                    if (i != steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          color: steps[i].isDone
                              ? scheme.primary.withValues(alpha: 0.4)
                              : scheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                    child: Row(
                      children: [
                        Text(
                          steps[i].label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: steps[i].isDone
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                            fontWeight: steps[i].isDone
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        if (steps[i].isDone)
                          Text(
                            formatDateTime(steps[i].at!),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
