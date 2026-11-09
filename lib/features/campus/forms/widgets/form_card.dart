import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../models/campus/campus_form.dart';
import '../../shared/status_chip.dart';

/// 表单卡片：标题、状态、已收进度、截止日期。
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.form, required this.onTap});

  final CampusForm form;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final open = form.isOpen;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        form.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    StatusChip(
                      label: form.status.label,
                      color: open ? scheme.primary : scheme.outline,
                    ),
                  ],
                ),
                if (form.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    form.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
                const SizedBox(height: AppTheme.spacingSm),
                Row(
                  children: [
                    StatusChip(
                      label: '已收 ${form.submissionCount}/${form.targetCount}',
                      color: scheme.secondary,
                      icon: Icons.inbox_outlined,
                    ),
                    const SizedBox(width: AppTheme.spacingXs),
                    StatusChip(
                      label: '${form.fields.length} 个题目',
                      color: scheme.onSurfaceVariant,
                    ),
                    if (form.mySubmitted) ...[
                      const SizedBox(width: AppTheme.spacingXs),
                      StatusChip(
                        label: '已提交',
                        color: scheme.primary,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXs),
                Row(
                  children: [
                    Text(
                      form.creatorName,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Text(
                      form.deadline == null ? '' : '${form.deadline} 截止',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
