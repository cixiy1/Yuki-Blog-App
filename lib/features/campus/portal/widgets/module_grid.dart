import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../shared/module_launcher.dart';

/// 六模块宫格。每格右上角带一个数字角标，表示该模块的待处理数量。
class ModuleGrid extends StatelessWidget {
  const ModuleGrid({
    super.key,
    required this.counts,
    required this.onTap,
  });

  /// key 是 [CampusModule.countKey]。
  final Map<String, int> counts;
  final void Function(CampusModule module) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppTheme.spacingSm,
      crossAxisSpacing: AppTheme.spacingSm,
      childAspectRatio: 2.5,
      children: [
        for (final module in CampusModule.values)
          _ModuleTile(
            module: module,
            count: counts[module.countKey] ?? 0,
            onTap: () => onTap(module),
          ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.count,
    required this.onTap,
  });

  final CampusModule module;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(module.icon, size: 19, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  module.label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: scheme.onError,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
