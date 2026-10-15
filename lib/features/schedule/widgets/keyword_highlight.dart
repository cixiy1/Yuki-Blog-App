import 'package:flutter/material.dart';

/// 关键词类别，与博客线 6 类高亮对应。
enum KwCategory { role, bld, subj, evt, act, neg }

/// 关键词 → 类别映射（与博客线 TT_KW_MAP 同步维护：
/// 博客改词表时这里要同步）。
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
final RegExp kwRegex = RegExp(
  (kwMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
      .map(RegExp.escape)
      .join('|'),
);

/// 把文本切成「普通文本 + 关键词片段」序列，供富文本渲染。
List<({String text, KwCategory? category})> splitKeywords(String content) {
  final result = <({String text, KwCategory? category})>[];
  var last = 0;
  for (final match in kwRegex.allMatches(content)) {
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

/// 单个类别的视觉规格（颜色取自亮/暗色板，与博客线一致）。
class KwStyle {
  const KwStyle({
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

KwStyle kwStyleOf(KwCategory cat, bool isDark) {
  switch (cat) {
    case KwCategory.role:
      return KwStyle(
        color: isDark ? const Color(0xFFB197FC) : const Color(0xFF9775FA),
        background: isDark ? const Color(0x339775FA) : const Color(0x299775FA),
      );
    case KwCategory.bld:
      return KwStyle(
        color: isDark ? const Color(0xFF8CE99A) : const Color(0xFF51CF66),
        background: isDark ? const Color(0x2E69DB7C) : const Color(0x2969DB7C),
      );
    case KwCategory.subj:
      return KwStyle(
        color: isDark ? const Color(0xFFFFA94D) : const Color(0xFFFF922B),
        border: const Color(0xFFFFA94D),
      );
    case KwCategory.evt:
      return KwStyle(
        color: isDark ? const Color(0xFF74C0FC) : const Color(0xFF4DABF7),
        background: isDark ? const Color(0x334DABF7) : const Color(0x294DABF7),
      );
    case KwCategory.act:
      return KwStyle(
        color: isDark ? const Color(0xFFFAA2C1) : const Color(0xFFF06595),
        underline: const Color(0xFFF783AC),
      );
    case KwCategory.neg:
      return KwStyle(
        color: const Color(0xFFFF8787),
        underline: const Color(0xFFFF6B6B),
        dashed: true,
      );
  }
}

/// 按关键词切分并生成富文本 span。
///
/// [baseStyle] 为普通文本样式；关键词在此基础上套 6 类视觉规格
/// （浅底 / 描边 / 下划线 / 虚线下划线，对应博客线 hlLog 的效果）。
List<InlineSpan> buildKeywordSpans(
  String content,
  TextStyle baseStyle,
  bool isDark,
) {
  final spans = <InlineSpan>[];
  for (final part in splitKeywords(content)) {
    if (part.category == null) {
      spans.add(TextSpan(text: part.text, style: baseStyle));
      continue;
    }
    final style = kwStyleOf(part.category!, isDark);
    final kwTextStyle = baseStyle.copyWith(
      color: style.color,
      fontWeight: FontWeight.w600,
      decoration:
          style.underline != null ? TextDecoration.underline : null,
      decorationColor: style.underline,
      decorationThickness: 2,
      decorationStyle: style.dashed
          ? TextDecorationStyle.dashed
          : TextDecorationStyle.solid,
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
              borderRadius:
                  style.border != null ? BorderRadius.circular(4) : null,
              border: style.border != null
                  ? Border.all(color: style.border!, width: 1.5)
                  : null,
            ),
            child: Text(part.text, style: kwTextStyle),
          ),
        ),
      );
    } else {
      spans.add(TextSpan(text: part.text, style: kwTextStyle));
    }
  }
  return spans;
}
