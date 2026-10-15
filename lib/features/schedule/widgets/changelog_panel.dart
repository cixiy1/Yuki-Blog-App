import 'package:flutter/material.dart';
import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/models/timetable.dart';

/// 8 色鲜艳色板（亮色主题），与博客线 --tt-log-c1..c8 一致。
const List<Color> _paletteLight = [
  Color(0xFFFF6B6B), // 红
  Color(0xFFFFA94D), // 橙
  Color(0xFFFFD43B), // 黄
  Color(0xFF69DB7C), // 绿
  Color(0xFF4DABF7), // 蓝
  Color(0xFF9775FA), // 紫
  Color(0xFFF783AC), // 粉
  Color(0xFF22B8CF), // 青
];

/// 8 色鲜艳色板（暗色主题，提亮变体），与博客线一致。
const List<Color> _paletteDark = [
  Color(0xFFFF8787),
  Color(0xFFFFC078),
  Color(0xFFFFE066),
  Color(0xFF8CE99A),
  Color(0xFF74C0FC),
  Color(0xFFB197FC),
  Color(0xFFFAA2C1),
  Color(0xFF66D9E8),
];

/// 数据更新历面板（多彩鲜艳风格，与博客线对齐）：
/// - 标题彩虹渐变文字
/// - 每条记录按 8 色循环：左侧色条 + 日期彩色徽章
/// - 最新一条高亮渐变底 + 「最新」角标
/// - 副标题「最近更新于」蓝色强调
class ChangelogPanel extends StatelessWidget {
  const ChangelogPanel({super.key, required this.meta});

  final TimetableMeta meta;

  @override
  Widget build(BuildContext context) {
    if (meta.changelog.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? _paletteDark : _paletteLight;
    final accent = palette[4]; // 蓝色强调（与博客 --tt-log-c5 对应）

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 彩虹渐变标题
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFFFF6B6B),
                    Color(0xFFFFA94D),
                    Color(0xFF4DABF7),
                    Color(0xFF9775FA),
                    Color(0xFFF783AC),
                  ],
                ).createShader(bounds),
                child: const Text(
                  '数据更新历',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '最近更新于 ${meta.updated}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          // 与博客线一致：条目多时限制高度滚动，避免撑爆课表页
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < meta.changelog.length; i++)
                    _ChangelogRow(
                      entry: meta.changelog[i],
                      color: palette[i % palette.length],
                      isLatest: i == 0,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条更新记录：色条 + 日期彩色徽章 + 内容（[isLatest] 时高亮 + 角标）。
class _ChangelogRow extends StatelessWidget {
  const _ChangelogRow({
    required this.entry,
    required this.color,
    required this.isLatest,
  });

  final ChangelogEntry entry;
  final Color color;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(top: isLatest ? 0 : 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: isLatest
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.16),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            )
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧彩色条
            Container(
              width: 4,
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            // 日期彩色徽章
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.date,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.content,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: scheme.onSurface,
                ),
              ),
            ),
            // 最新角标
            if (isLatest) ...[
              const SizedBox(width: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '最新',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
