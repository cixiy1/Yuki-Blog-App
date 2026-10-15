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

/// 关键词类别，与博客线 6 类高亮对应。
enum KwCategory { role, bld, subj, evt, act, neg }

/// 关键词 → 类别映射（与博客线 TT_KW_MAP 同步维护）。
const Map<String, KwCategory> kwMap = {
  '团支书': KwCategory.role,
  '班长': KwCategory.role,
  '修德楼': KwCategory.bld,
  '强能楼': KwCategory.bld,
  '习概': KwCategory.subj,
  'Web': KwCategory.subj,
  'Java': KwCategory.subj,
  '军事理论': KwCategory.subj,
  '晚自习': KwCategory.evt,
  '体测': KwCategory.evt,
  '入党谈话': KwCategory.evt,
  '团籍资料': KwCategory.evt,
  '班委竞选': KwCategory.evt,
  '反诈': KwCategory.evt,
  '军训': KwCategory.evt,
  '机房': KwCategory.evt,
  '劳动实践': KwCategory.evt,
  '宿舍': KwCategory.evt,
  '改为': KwCategory.act,
  '换至': KwCategory.act,
  '新增': KwCategory.act,
  '落实': KwCategory.act,
  '调整': KwCategory.act,
  '归档': KwCategory.act,
  '取消': KwCategory.neg,
  '停课': KwCategory.neg,
};

/// 高亮正则：长词优先，避免「劳动实践」被「劳动」类短词截断。
final RegExp _kwRegex = RegExp(
  (kwMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length)))
      .map(RegExp.escape)
      .join('|'),
);

/// 把更新历正文切成「普通文本 + 关键词片段」序列，供富文本渲染。
List<({String text, KwCategory? category})> splitKeywords(String content) {
  final result = <({String text, KwCategory? category})>[];
  var last = 0;
  for (final match in _kwRegex.allMatches(content)) {
    if (match.start > last) {
      result.add((text: content.substring(last, match.start), category: null));
    }
    result.add((
      text: match.group(0)!,
      category: kwMap[match.group(0)] ?? KwCategory.evt,
    ));
    last = match.end;
  }
  if (last < content.length) {
    result.add((text: content.substring(last), category: null));
  }
  return result;
}

/// 单个类别的视觉规格（颜色取自亮/暗色板）。
class _KwStyle {
  const _KwStyle({
    required this.color,
    this.background,
    this.border,
    this.underline,
    this.dashed = false,
  });

  final Color color;
  final Color? background;
  final Color? border;
  final Color? underline;
  final bool dashed;
}

_KwStyle _styleOf(KwCategory cat, bool isDark) {
  switch (cat) {
    case KwCategory.role:
      return _KwStyle(
        color: isDark ? const Color(0xFFB197FC) : const Color(0xFF9775FA),
        background: isDark ? const Color(0x339775FA) : const Color(0x299775FA),
      );
    case KwCategory.bld:
      return _KwStyle(
        color: isDark ? const Color(0xFF8CE99A) : const Color(0xFF51CF66),
        background: isDark ? const Color(0x2E69DB7C) : const Color(0x2969DB7C),
      );
    case KwCategory.subj:
      return _KwStyle(
        color: isDark ? const Color(0xFFFFA94D) : const Color(0xFFFF922B),
        border: isDark ? const Color(0xFFFFA94D) : const Color(0xFFFFA94D),
      );
    case KwCategory.evt:
      return _KwStyle(
        color: isDark ? const Color(0xFF74C0FC) : const Color(0xFF4DABF7),
        background: isDark ? const Color(0x334DABF7) : const Color(0x294DABF7),
      );
    case KwCategory.act:
      return _KwStyle(
        color: isDark ? const Color(0xFFFAA2C1) : const Color(0xFFF06595),
        underline: isDark ? const Color(0xFFF783AC) : const Color(0xFFF783AC),
      );
    case KwCategory.neg:
      return _KwStyle(
        color: isDark ? const Color(0xFFFF8787) : const Color(0xFFFF8787),
        underline: const Color(0xFFFF6B6B),
        dashed: true,
      );
  }
}

/// 数据更新历面板（多彩鲜艳风格，与博客线对齐并有 App 侧竖排布局）：
/// - 标题彩虹渐变文字，副标题「最近更新于」蓝色强调
/// - 每条记录按 8 色循环：左侧色条 + 日期彩色徽章
/// - 正文按 6 类关键词高亮（角色/楼宇/科目/事项/动作/负面动作）
/// - 竖排：日期徽章独占上行，正文占满整行（手机端更舒展）
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
                      isDark: isDark,
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

/// 单条更新记录（竖排）：左侧色条，上行日期徽章，下行富文本正文。
class _ChangelogRow extends StatelessWidget {
  const _ChangelogRow({
    required this.entry,
    required this.color,
    required this.isLatest,
    required this.isDark,
  });

  final ChangelogEntry entry;
  final Color color;
  final bool isLatest;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(top: isLatest ? 0 : 2),
      padding: const EdgeInsets.only(left: 14, top: 9, bottom: 9, right: 6),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上行：日期徽章 + 最新角标
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
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
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      if (isLatest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5),
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
                  const SizedBox(height: 5),
                  // 下行：关键词高亮正文
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: scheme.onSurface,
                      ),
                      children: _buildSpans(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context) {
    final spans = <InlineSpan>[];
    for (final part in splitKeywords(entry.content)) {
      if (part.category == null) {
        spans.add(TextSpan(text: part.text));
        continue;
      }
      final style = _styleOf(part.category!, isDark);
      final textStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: style.color,
        decoration: style.underline != null
            ? TextDecoration.underline
            : TextDecoration.none,
        decorationColor: style.underline,
        decorationThickness: 2,
        decorationStyle:
            style.dashed ? TextDecorationStyle.dashed : TextDecorationStyle.solid,
      );
      if (style.background != null || style.border != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 3,
                vertical: style.border != null ? 0.5 : 1,
              ),
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: style.border != null
                    ? BorderRadius.circular(4)
                    : null,
                border: style.border != null
                    ? Border.all(color: style.border!, width: 1.5)
                    : null,
              ),
              child: Text(part.text, style: textStyle),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: part.text, style: textStyle));
      }
    }
    return spans;
  }
}
