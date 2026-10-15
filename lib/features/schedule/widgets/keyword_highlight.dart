import 'package:flutter/material.dart';

/// 关键词类别，与博客线 6 类高亮对应。
enum KwCategory { role, bld, subj, evt, act, neg }

/// 关键词 → 类别映射（与博客线 TT_KW_MAP 同步维护：
/// 博客改词表时这里要同步）。
const Map<String, KwCategory> kwMap = {
  // 角色
  '团支书': KwCategory.role,
  '班长': KwCategory.role,
  '辅导员': KwCategory.role,
  '班委': KwCategory.role,
  '团委': KwCategory.role,
  '学生会': KwCategory.role,
  '党支部': KwCategory.role,
  '党员': KwCategory.role,
  '预备党员': KwCategory.role,
  // 楼宇 / 地点
  '修德楼': KwCategory.bld,
  '强能楼': KwCategory.bld,
  '教学楼': KwCategory.bld,
  '大礼堂': KwCategory.bld,
  'G1楼': KwCategory.bld,
  '机房': KwCategory.bld,
  '宿舍': KwCategory.bld,
  '图书馆': KwCategory.bld,
  '实验楼': KwCategory.bld,
  '报告厅': KwCategory.bld,
  '体育馆': KwCategory.bld,
  '操场': KwCategory.bld,
  '食堂': KwCategory.bld,
  // 科目
  '习概': KwCategory.subj,
  'Web': KwCategory.subj,
  'Java': KwCategory.subj,
  'C语言': KwCategory.subj,
  '军事理论': KwCategory.subj,
  '体育': KwCategory.subj,
  '高数': KwCategory.subj,
  '英语': KwCategory.subj,
  '数据结构': KwCategory.subj,
  '计算机网络': KwCategory.subj,
  '数据库': KwCategory.subj,
  '线性代数': KwCategory.subj,
  // 事项
  '晚自习': KwCategory.evt,
  '早自习': KwCategory.evt,
  '体测': KwCategory.evt,
  '入党谈话': KwCategory.evt,
  '入党积极分子': KwCategory.evt,
  '入党': KwCategory.evt,
  '思想汇报': KwCategory.evt,
  '团籍资料': KwCategory.evt,
  '班委竞选': KwCategory.evt,
  '反诈': KwCategory.evt,
  '军训': KwCategory.evt,
  '劳动实践': KwCategory.evt,
  '考试': KwCategory.evt,
  '讲座': KwCategory.evt,
  '抽查': KwCategory.evt,
  '返校': KwCategory.evt,
  '放假': KwCategory.evt,
  '调休': KwCategory.evt,
  '选课': KwCategory.evt,
  '报到': KwCategory.evt,
  '缴费': KwCategory.evt,
  '消防演练': KwCategory.evt,
  '运动会': KwCategory.evt,
  '班会': KwCategory.evt,
  '团课': KwCategory.evt,
  '党课': KwCategory.evt,
  '升旗': KwCategory.evt,
  '查寝': KwCategory.evt,
  '晚点名': KwCategory.evt,
  '元旦': KwCategory.evt,
  '中秋': KwCategory.evt,
  '国庆': KwCategory.evt,
  '寒假': KwCategory.evt,
  '暑假': KwCategory.evt,
  // 动作
  '改为': KwCategory.act,
  '换至': KwCategory.act,
  '新增': KwCategory.act,
  '落实': KwCategory.act,
  '调整': KwCategory.act,
  '归档': KwCategory.act,
  '顺延': KwCategory.act,
  '提前': KwCategory.act,
  '推迟': KwCategory.act,
  '改期': KwCategory.act,
  '迁移': KwCategory.act,
  '替换': KwCategory.act,
  '提交': KwCategory.act,
  '上报': KwCategory.act,
  '领取': KwCategory.act,
  '填写': KwCategory.act,
  // 负面动作
  '取消': KwCategory.neg,
  '停课': KwCategory.neg,
  '停电': KwCategory.neg,
  '停水': KwCategory.neg,
  '暂停': KwCategory.neg,
  '延期': KwCategory.neg,
  '作废': KwCategory.neg,
  '中止': KwCategory.neg,
};

/// 高亮正则：长词优先，避免「劳动实践」被「劳动」类短词截断。
final RegExp kwRegex = RegExp(
  (kwMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length)))
      .map(RegExp.escape)
      .join('|'),
);

/// 「划词连片」允许与关键词相连的字符：数字 / 字母 / 中文数字 /
/// 楼栋房间与周次时间的计量字。例：「G1楼401机房」「第12周考试」
/// 会连成一个色块，而不是只标「机房」「考试」。
const String unitChars =
    '0123456789一二三四五六七八九十百千零两第楼栋号室层周月日年点时分秒节上下午晚';

bool _isAlphaNum(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A);
}

bool _isUnitChar(String ch) => _isAlphaNum(ch) || unitChars.contains(ch);

/// 一段高亮区间：关键词连同相邻计量前缀的起止下标与类别。
class KwRange {
  const KwRange(this.start, this.end, this.category);

  final int start;
  final int end;
  final KwCategory category;
}

/// 计算文本里的全部高亮区间。
///
/// 实体类关键词（role/bld/subj/evt）会向左吞并计量前缀、向右吞并
/// 纯数字字母后缀连成一片，但不越过相邻关键词（避免「周五机房停电」
/// 里「停电」被楼宇连片吞掉、丢失负面标记）；act/neg 是动词，不连片
/// （避免「第5周改为」整段变红粉色）。相邻区间重叠时合并、保留前段类别。
List<KwRange> highlightRanges(String content) {
  final raw = <(int, int, KwCategory)>[];
  for (final m in kwRegex.allMatches(content)) {
    raw.add((m.start, m.end, kwMap[m.group(0)!] ?? KwCategory.evt));
  }
  final ranges = <KwRange>[];
  for (var i = 0; i < raw.length; i++) {
    final (ms, me, cat) = raw[i];
    var s = ms;
    var e = me;
    if (cat != KwCategory.act && cat != KwCategory.neg) {
      final leftLimit = i == 0 ? 0 : raw[i - 1].$2;
      while (s > leftLimit && _isUnitChar(content[s - 1])) {
        s--;
      }
      final rightLimit =
          i + 1 < raw.length ? raw[i + 1].$1 : content.length;
      while (e < rightLimit && _isAlphaNum(content[e])) {
        e++;
      }
    }
    final prev = ranges.isEmpty ? null : ranges.last;
    if (prev != null && s < prev.end) {
      if (e > prev.end) {
        ranges[ranges.length - 1] = KwRange(prev.start, e, prev.category);
      }
    } else {
      ranges.add(KwRange(s, e, cat));
    }
  }
  return ranges;
}

/// 「划句」句子区间：按 。！？；换行 分句，标点归前一句。
List<({int start, int end})> sentenceRanges(String content) {
  const stops = '。！？；\n';
  final out = <({int start, int end})>[];
  var start = 0;
  for (var i = 0; i < content.length; i++) {
    if (stops.contains(content[i])) {
      out.add((start: start, end: i + 1));
      start = i + 1;
    }
  }
  if (start < content.length) {
    out.add((start: start, end: content.length));
  }
  return out;
}

/// 把文本切成「普通文本 + 关键词片段」序列，供富文本渲染。
/// 切分基于 [highlightRanges]（含连片），与渲染端行为一致。
List<({String text, KwCategory? category})> splitKeywords(String content) {
  final result = <({String text, KwCategory? category})>[];
  var last = 0;
  for (final r in highlightRanges(content)) {
    if (r.start > last) {
      result.add((text: content.substring(last, r.start), category: null));
    }
    result.add((text: content.substring(r.start, r.end), category: r.category));
    last = r.end;
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
    this.wavy = false,
  });

  final Color color;
  final Color? background;
  final Color? border;
  final Color? underline;
  final bool dashed;
  final bool wavy;
}

KwStyle kwStyleOf(KwCategory cat, bool isDark) {
  switch (cat) {
    case KwCategory.role:
      final color = isDark ? const Color(0xFFB197FC) : const Color(0xFF9775FA);
      return KwStyle(
        color: color,
        background: isDark ? const Color(0x339775FA) : const Color(0x299775FA),
        underline: color,
        wavy: true,
      );
    case KwCategory.bld:
      final color = isDark ? const Color(0xFF8CE99A) : const Color(0xFF51CF66);
      return KwStyle(
        color: color,
        background: isDark ? const Color(0x2E69DB7C) : const Color(0x2969DB7C),
        underline: color,
      );
    case KwCategory.subj:
      return KwStyle(
        color: isDark ? const Color(0xFFFFA94D) : const Color(0xFFFF922B),
        border: const Color(0xFFFFA94D),
        underline: const Color(0xFFFF922B),
      );
    case KwCategory.evt:
      final color = isDark ? const Color(0xFF74C0FC) : const Color(0xFF4DABF7);
      return KwStyle(
        color: color,
        background: isDark ? const Color(0x334DABF7) : const Color(0x294DABF7),
        underline: color,
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

/// 「划句」底色：整句含重点词时铺一层很淡的荧光黄，像手写划重点。
const Color _sentenceBgLight = Color(0x2EFFD43B);
const Color _sentenceBgDark = Color(0x1AFFD43B);

Paint _bgPaint(Color color) => Paint()..color = color;

TextSpan _plainSpan(String text, TextStyle base, Color? sentenceBg) =>
    TextSpan(
      text: text,
      style: sentenceBg == null
          ? base
          : base.copyWith(background: _bgPaint(sentenceBg)),
    );

InlineSpan _kwSpan(
  String text,
  KwCategory cat,
  TextStyle base,
  bool isDark,
  Color? sentenceBg,
) {
  final style = kwStyleOf(cat, isDark);
  final kwTextStyle = base.copyWith(
    color: style.color,
    fontWeight: FontWeight.w600,
    background: sentenceBg == null ? null : _bgPaint(sentenceBg),
    decoration:
        style.underline != null ? TextDecoration.underline : null,
    decorationColor: style.underline,
    decorationThickness: 2,
    decorationStyle: style.dashed
        ? TextDecorationStyle.dashed
        : (style.wavy ? TextDecorationStyle.wavy : TextDecorationStyle.solid),
  );
  // 只靠文字样式表达的类别（act/neg：下划线/虚线）不套底色药丸，
  // 划句底色直接由 TextStyle.background 承担。
  if (style.background == null && style.border == null) {
    return TextSpan(text: text, style: kwTextStyle);
  }
  Widget child = Container(
    padding: EdgeInsets.symmetric(
      horizontal: 3,
      vertical: style.border != null ? 0.5 : 1,
    ),
    decoration: BoxDecoration(
      color: style.background,
      borderRadius: style.border != null ? BorderRadius.circular(4) : null,
      border: style.border != null
          ? Border.all(color: style.border!, width: 1.5)
          : null,
    ),
    child: Text(text, style: kwTextStyle),
  );
  if (sentenceBg != null) {
    // 划句底色垫在高亮词片下面，让整句的荧光层连续。
    child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: sentenceBg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: child,
    );
  }
  return WidgetSpan(alignment: PlaceholderAlignment.middle, child: child);
}

/// 按句子 + 关键词切分并生成富文本 span。
///
/// [baseStyle] 为普通文本样式。三层结构：
/// 1. 划句：含重点词的整句铺淡荧光黄底；
/// 2. 划词：关键词按 6 类视觉规格着色（浅底 / 描边 / 划线叠加），
///    并与相邻的楼栋、房间号、周次、时间连成一片；
/// 3. 划线：高亮词本身叠加同色划线（波浪 / 直线 / 虚线）。
List<InlineSpan> buildKeywordSpans(
  String content,
  TextStyle baseStyle,
  bool isDark,
) {
  final ranges = highlightRanges(content);
  if (ranges.isEmpty) {
    return content.isEmpty
        ? const <InlineSpan>[]
        : <InlineSpan>[TextSpan(text: content, style: baseStyle)];
  }
  final spans = <InlineSpan>[];
  for (final sent in sentenceRanges(content)) {
    final hits = ranges
        .where((r) => r.start < sent.end && r.end > sent.start)
        .toList();
    final sentenceBg =
        hits.isEmpty ? null : (isDark ? _sentenceBgDark : _sentenceBgLight);
    var pos = sent.start;
    for (final r in hits) {
      final s = r.start < pos ? pos : r.start;
      final e = r.end > sent.end ? sent.end : r.end;
      if (s > pos) {
        spans.add(_plainSpan(content.substring(pos, s), baseStyle, sentenceBg));
      }
      spans.add(
        _kwSpan(
          content.substring(s, e),
          r.category,
          baseStyle,
          isDark,
          sentenceBg,
        ),
      );
      pos = e;
    }
    if (pos < sent.end) {
      spans.add(
        _plainSpan(content.substring(pos, sent.end), baseStyle, sentenceBg),
      );
    }
  }
  return spans;
}
