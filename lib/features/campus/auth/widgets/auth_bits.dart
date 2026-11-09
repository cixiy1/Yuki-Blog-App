import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// 登录 / 注册页顶部的品牌区。
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({
    super.key,
    this.title = '校园服务',
    this.subtitle = '失物招领 · 二手闲置 · 跑腿代取 · 活动表单',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Icon(Icons.apartment_rounded,
              size: 32, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppTheme.spacingXs),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// 表单顶部的错误条。
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
