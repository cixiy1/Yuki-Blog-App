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
  '班主任': KwCategory.role,
  '班委': KwCategory.role,
  '团委': KwCategory.role,
  '学生会': KwCategory.role,
  '党支部': KwCategory.role,
  '党员': KwCategory.role,
  '预备党员': KwCategory.role,
  '负责人': KwCategory.role,
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
  '田径场': KwCategory.bld,
  '看台': KwCategory.bld,
  '操场': KwCategory.bld,
  '食堂': KwCategory.bld,
  '北校区': KwCategory.bld,
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
  '体质健康测试': KwCategory.evt,
  '免测': KwCategory.evt,
  '入党谈话': KwCategory.evt,
  '入党积极分子': KwCategory.evt,
  '入党': KwCategory.evt,
  '思想汇报': KwCategory.evt,
  '团籍资料': KwCategory.evt,
  '班委竞选': KwCategory.evt,
  '反诈': KwCategory.evt,
  '军训服装': KwCategory.evt,
  '军训': KwCategory.evt,
  '劳动实践': KwCategory.evt,
  '考试': KwCategory.evt,
  '讲座': KwCategory.evt,
  '抽查': KwCategory.evt,
  '考勤': KwCategory.evt,
  '点名': KwCategory.evt,
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
  '请假': KwCategory.act,
  '办理': KwCategory.act,
  '购买': KwCategory.act,
  '携带': KwCategory.act,
  '参加': KwCategory.act,
  '报名': KwCategory.act,
  '核对': KwCategory.act,
  '申请': KwCategory.act,
  '履行': KwCategory.act,
  '到场': KwCategory.act,
  '完成': KwCategory.act,
  // 负面动作
  '取消': KwCategory.neg,
  '停课': KwCategory.neg,
  '停电': KwCategory.neg,
  '停水': KwCategory.neg,
  '暂停': KwCategory.neg,
  '延期': KwCategory.neg,
  '作废': KwCategory.neg,
  '中止': KwCategory.neg,
  '旷课': KwCategory.neg,
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

// ---------------------------------------------------------------------------
// 人工标注：读懂内容后手动标出「哪一段值得看」
// ---------------------------------------------------------------------------
//
// 纯算法回答不了「这条要不要我现在处理」——它只会认词形和锚点。
// 所以正式数据里由人（写数据的人）读一遍，把值得看的片段用成对括号标出来：
//
//   {{...}}  必看（core）—— 时间、地点、必须办的事
//   [[...]]  关注（key）—— 相关但不必马上处理
//   ((...))  一般（plain）—— 显式压档：讲工具本身、读者不必处理的内容
//
// 标记直接内联在正文里，因此改文字时标记跟着文字走，不像字符下标那样一改就错位。
// 渲染前会整段剥离，不会显示出来。
//
// 与算法的分工：
//   · 档位（必看 / 关注 / 一般）—— 只要正文里出现过标注，这一整段就视为
//     「已人工审阅」，全部以标注为准（没标的句子就是一般），算法不参与；
//     整段一个标注都没有时才回退到 [analyseSentences] 兜底（未审阅内容）。
//   · 配色（角色 / 楼宇 / 科目 / 事项 / 动作 / 负面）—— 始终由 [kwMap] 词表决定。
// 这样「人工判断重要性」与「固定词表给颜色」各司其职，互不打架。

/// 一段人工标注区间（下标基于剥离标记后的正文）。
class MarkSpan {
  const MarkSpan(this.start, this.end, this.tier);

  final int start;
  final int end;
  final ImportanceTier tier;
}

/// 剥离标注后的正文 + 标注区间。
class AnnotatedText {
  const AnnotatedText(this.text, this.marks);

  /// 剥掉标记的纯正文（渲染与算法都基于它）。
  final String text;

  /// 标注区间，按下标升序。
  final List<MarkSpan> marks;

  /// 这段文字是否被人工标注过。有标注时算法不再插手定档。
  bool get isAnnotated => marks.isNotEmpty;
}

const String _markOpenCore = '{{';
const String _markCloseCore = '}}';
const String _markOpenKey = '[[';
const String _markCloseKey = ']]';
const String _markOpenPlain = '((';
const String _markClosePlain = '))';

/// 解析内联标注：双花括号=必看，双方括号=关注，双圆括号=一般（显式压档）。
///
/// 括号不成对时按普通文字处理（宁可少标一处，不可悄悄吞掉原文）。
AnnotatedText parseAnnotations(String raw) {
  if (!raw.contains('{') && !raw.contains('[') && !raw.contains('((')) {
    return AnnotatedText(raw, const <MarkSpan>[]);
  }
  final buf = StringBuffer();
  final marks = <MarkSpan>[];
  var i = 0;
  while (i < raw.length) {
    final open2 = i + 1 < raw.length ? raw.substring(i, i + 2) : '';
    final String? close;
    final ImportanceTier tier;
    if (open2 == _markOpenCore) {
      close = _markCloseCore;
      tier = ImportanceTier.core;
    } else if (open2 == _markOpenKey) {
      close = _markCloseKey;
      tier = ImportanceTier.key;
    } else if (open2 == _markOpenPlain) {
      close = _markClosePlain;
      tier = ImportanceTier.plain;
    } else {
      close = null;
      tier = ImportanceTier.plain;
    }
    if (close != null) {
      final end = raw.indexOf(close, i + 2);
      if (end > i + 2) {
        final seg = raw.substring(i + 2, end);
        final start = buf.length;
        buf.write(seg);
        marks.add(MarkSpan(start, start + seg.length, tier));
        i = end + 2;
        continue;
      }
    }
    buf.write(raw[i]);
    i++;
  }
  return AnnotatedText(buf.toString(), marks);
}

/// 某一句的档位。
///
/// [annotated] 为整段是否有标注：有则只认标注（没标的句子就是「一般」，
/// 不让算法猜回来），无则回退到语义评分。
ImportanceTier sentenceTierOf(
  String clean,
  int ss,
  int se,
  List<MarkSpan> marks,
  List<KwRange> ranges, {
  required bool annotated,
}) {
  if (annotated) {
    var hasKey = false;
    for (final m in marks) {
      if (m.start >= se || m.end <= ss) continue;
      if (m.tier == ImportanceTier.core) return ImportanceTier.core;
      if (m.tier == ImportanceTier.key) hasKey = true;
    }
    return hasKey ? ImportanceTier.key : ImportanceTier.plain;
  }
  return analyseSentence(clean, ss, se, ranges: ranges).tier;
}

// ---------------------------------------------------------------------------
// 语义重点度：读懂一句话再判断它值不值得看
// ---------------------------------------------------------------------------
//
// 词表只能识别「这是楼宇」「这是科目」，回答不了「这条信息要不要我现在处理」。
// 真正决定一条信息重不重要的是四类锚点：
//   ① 时空锚点 —— 什么时候 / 在哪里（读者据此决定要不要记进日程）
//   ② 行动锚点 —— 要求 + 具体动作（读者据此决定要做什么）
//   ③ 影响锚点 —— 对象范围、变更、负面（影响面与风险）
//   ④ 元信息    —— 讲的是工具本身（面板/配色/构建）而不是班级事务 → 降权
// 三类锚点算加权分，再按档位渲染：core 必看 / key 关注 / plain 一般。

/// 重点度档位。
enum ImportanceTier {
  /// 必看：含时空锚点或「要求 + 具体动作」，读者必须处理。
  core,

  /// 关注：与读者相关但不紧急。
  key,

  /// 一般：补充说明、明细罗列，不抢注意力。
  plain,
}

/// 一句话的语义分析结果。
class SentenceInfo {
  const SentenceInfo({
    required this.start,
    required this.end,
    required this.tier,
    required this.score,
    required this.tags,
  });

  final int start;
  final int end;
  final ImportanceTier tier;
  final double score;

  /// 命中的锚点标签（time / place / deadline / require / action /
  /// scope / change / notice / neg / event / meta），便于调试与测试。
  final Set<String> tags;

  bool has(String tag) => tags.contains(tag);
}

// 时刻 / 日期 / 日期区间 / 点钟。数字型时间一律走正则，不依赖词表。
final RegExp _reTime = RegExp(
  r'\d{1,2}\s*[:：]\s*\d{2}'
  r'|\d{1,2}\s*月\s*\d{1,2}\s*[日号]'
  r'|\d{1,2}\s*/\s*\d{1,2}'
  r'|\d{1,2}\s*[-–—~～至到]\s*\d{1,2}'
  r'|\d{1,2}\s*[点时]',
);
// 周次 / 星期。
final RegExp _reWeek = RegExp(r'第\s*\d+\s*周|\d+\s*周|周[一二三四五六日天末]');
// 半天时段。
final RegExp _reDayPart = RegExp(r'上午|下午|晚上|中午|早上|凌晨');
// 相对时间与「自…起」。
final RegExp _reRelative = RegExp(r'今天|明天|后天|下周|本周|本周末|自.{0,12}?起');
// 截止/紧迫。
final RegExp _reDeadline = RegExp(r'截止|之前|以前|以内|前完成|前提交|前交|尽早|尽快|逾期');
// 地点后缀。不能用一个笼统的「任意中文 + 楼馆厅场室房区」：
// 「2026级室内」会被切成「级室」、「广东省教育厅」会被当成「教育厅」。
// 所以逐类收口——「室」排除后接「内/外」，「厅」只认会场类词。
final RegExp _rePlaceSuffix = RegExp(
  r'[\u4e00-\u9fa5]{1,4}楼'
  r'|[\u4e00-\u9fa5]{1,4}室(?![内外])'
  r'|[\u4e00-\u9fa5]{1,4}馆'
  r'|[\u4e00-\u9fa5]{1,4}房'
  r'|礼堂|报告厅|音乐厅|多功能厅|大厅'
  r'|田径场|球场|操场|篮球场|足球场|排球场|羽毛球场|网球场|广场'
  r'|空地|看台|校区',
);
// 强制/提示语气。「请」前面是「申」时不算（申请）。
final RegExp _reRequire =
    RegExp(r'务必|必须|须|不得|禁止|注意|切记|记得|按时|准时|要求|需要|(?:^|[^申])请');
// 具体行动词：读者要动手做的事。
final RegExp _reAction = RegExp(
  r'填写|提交|上报|领取|办理|准备|带上|携带|参加|出席|报名|缴费|购买'
  r'|交至|交到|交至本班|完成|申请|签字|核对|确认|请假|履行|到场|分流',
);
// 影响面：全体 / 各班 / 每人。
final RegExp _reScope = RegExp(r'全体|所有|各班|每人|全员|全班|不漏一人|都要|每位|负责人');
// 时间/地点/内容的变更。
final RegExp _reChange =
    RegExp(r'改为|换成|换至|调课|补课|停课|取消|新增|推迟|顺延|提前|调整|搬迁|迁移|替换|变更');
// 通知类标记。
final RegExp _reNotice = RegExp(r'通知|公告|提醒|告知|另行|留意|为准');
// 具体数字（越具体越值得看）。
final RegExp _reDigits = RegExp(r'\d');
// 元信息：讲的是工具本身而不是班级事务 → 降权。
final RegExp _reMeta = RegExp(
  r'面板|标识|角标|配色|色板|界面|版式|样式|字体|布局|动画|交互|高亮|划词|划句'
  r'|组件|字段|接口|缓存|离线|弹窗|版本|仓库|构建|部署|博客|App|后台|脚本|数据源'
  r'|修复|优化|重构|回退|兜底|正文|条目|功能|支持|标签|格式|引用|来源|updated'
  r'|meta\.',
);

/// 给一句话打分并定档。
SentenceInfo analyseSentence(
  String content,
  int start,
  int end, {
  List<KwRange>? ranges,
}) {
  final text = content.substring(start, end);
  final rs = ranges ?? highlightRanges(content);
  final tags = <String>{};

  var hasEvt = false;
  var hasBld = false;
  var hasNeg = false;
  for (final r in rs) {
    if (r.start >= end || r.end <= start) continue;
    switch (r.category) {
      case KwCategory.bld:
        hasBld = true;
      case KwCategory.evt:
        hasEvt = true;
      case KwCategory.neg:
        hasNeg = true;
      default:
        break;
    }
  }

  var score = 0.0;

  if (_reTime.hasMatch(text)) {
    score += 3;
    tags.add('time');
  }
  if (_reWeek.hasMatch(text)) {
    score += 2;
    tags.add('time');
  }
  if (_reDayPart.hasMatch(text)) {
    score += 1.5;
    tags.add('time');
  }
  if (_reRelative.hasMatch(text)) {
    score += 2;
    tags.add('time');
  }
  if (_reDeadline.hasMatch(text)) {
    score += 2.5;
    tags.add('deadline');
  }
  if (hasBld || _rePlaceSuffix.hasMatch(text)) {
    score += 2.5;
    tags.add('place');
  }

  final require = _reRequire.hasMatch(text);
  final action = _reAction.hasMatch(text);
  if (require) {
    score += 2.5;
    tags.add('require');
  }
  if (action) {
    score += 2;
    tags.add('action');
  }

  if (hasEvt) {
    score += 1;
    tags.add('event');
  }
  if (hasNeg) {
    score += 2;
    tags.add('neg');
  }
  if (_reScope.hasMatch(text)) {
    score += 2;
    tags.add('scope');
  }
  if (_reChange.hasMatch(text)) {
    score += 1.5;
    tags.add('change');
  }
  if (_reNotice.hasMatch(text)) {
    score += 1.5;
    tags.add('notice');
  }
  if (_reDigits.hasMatch(text)) {
    score += 0.5;
  }

  final metaHits = _reMeta.allMatches(text).length;
  if (metaHits > 0) {
    score -= 3.0 * (metaHits > 2 ? 2 : metaHits);
    tags.add('meta');
  }

  // 定档规则：光有语气词（「请注意」）不算必看，
  // 必须落到「时空锚点」或「要求 + 具体动作」上才算。
  final anchored =
      tags.contains('time') || tags.contains('place') || tags.contains('deadline');
  final actionable = require && action;

  final ImportanceTier tier;
  if ((anchored && score >= 4.5) || (actionable && score >= 5) || score >= 9) {
    tier = ImportanceTier.core;
  } else if (score >= 2) {
    tier = ImportanceTier.key;
  } else {
    tier = ImportanceTier.plain;
  }

  return SentenceInfo(
    start: start,
    end: end,
    tier: tier,
    score: score,
    tags: tags,
  );
}

/// 逐句分析整段文本的重点度。
List<SentenceInfo> analyseSentences(String content, {List<KwRange>? ranges}) {
  final rs = ranges ?? highlightRanges(content);
  return [
    for (final s in sentenceRanges(content))
      analyseSentence(content, s.start, s.end, ranges: rs),
  ];
}

/// 把文本切成「普通文本 + 关键词片段」序列，供富文本渲染。
/// 切分基于 [highlightRanges]（含连片），与渲染端行为一致；
/// 内联标注会被剥离（标注只影响定档，不影响分词）。
List<({String text, KwCategory? category})> splitKeywords(String content) {
  final clean = parseAnnotations(content).text;
  final result = <({String text, KwCategory? category})>[];
  var last = 0;
  for (final r in highlightRanges(clean)) {
    if (r.start > last) {
      result.add((text: clean.substring(last, r.start), category: null));
    }
    result.add((text: clean.substring(r.start, r.end), category: r.category));
    last = r.end;
  }
  if (last < clean.length) {
    result.add((text: clean.substring(last), category: null));
  }
  return result;
}

/// 单个类别的视觉规格（颜色取自亮/暗色板，与博客线一致）。
///
/// 密度取舍：关键词一律**不用底色块、不用描边框**，只用「着色 + 同色划线」
/// 表达类别——底色只留给「必看句」一个层级，避免彩块叠在荧光底上显得杂乱。
/// 六类的区分靠颜色 + 划线样式（波浪 / 实线 / 点线 / 虚线）。
class KwStyle {
  const KwStyle({
    required this.color,
    this.underline,
    this.dashed = false,
    this.dotted = false,
    this.wavy = false,
  });

  final Color color;
  final Color? underline;
  final bool dashed;
  final bool dotted;
  final bool wavy;
}

KwStyle kwStyleOf(KwCategory cat, bool isDark) {
  switch (cat) {
    case KwCategory.role:
      final color = isDark ? const Color(0xFFB197FC) : const Color(0xFF9775FA);
      return KwStyle(color: color, underline: color, wavy: true);
    case KwCategory.bld:
      final color = isDark ? const Color(0xFF8CE99A) : const Color(0xFF51CF66);
      return KwStyle(color: color, underline: color);
    case KwCategory.subj:
      final color = isDark ? const Color(0xFFFFA94D) : const Color(0xFFFF922B);
      return KwStyle(color: color, underline: color, dotted: true);
    case KwCategory.evt:
      final color = isDark ? const Color(0xFF74C0FC) : const Color(0xFF4DABF7);
      return KwStyle(color: color, underline: color);
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

/// 划句底色：只给「必看」句铺一层淡荧光黄 + 句首竖条。
/// 「关注」句不铺底色（靠标注片段加粗体现），否则一屏里黄底连片、反而看不出重点。
const Color _coreBgLight = Color(0x38FFD43B);
const Color _coreBgDark = Color(0x24FFD43B);

/// 必看句的句首竖条标记色。
const Color _coreMarkLight = Color(0xFFFFA000);
const Color _coreMarkDark = Color(0xFFFFD43B);

Color? sentenceBgOf(ImportanceTier tier, bool isDark) {
  switch (tier) {
    case ImportanceTier.core:
      return isDark ? _coreBgDark : _coreBgLight;
    case ImportanceTier.key:
    case ImportanceTier.plain:
      return null;
  }
}

Paint _bgPaint(Color color) => Paint()..color = color;

TextSpan _plainSpan(
  String text,
  TextStyle base,
  Color? sentenceBg, {
  bool emphasis = false,
}) =>
    TextSpan(
      text: text,
      style: base.copyWith(
        background: sentenceBg == null ? null : _bgPaint(sentenceBg),
        fontWeight: emphasis ? FontWeight.w600 : base.fontWeight,
      ),
    );

InlineSpan _kwSpan(
  String text,
  KwCategory cat,
  TextStyle base,
  bool isDark,
  Color? sentenceBg, {
  bool emphasis = false,
}) {
  final style = kwStyleOf(cat, isDark);
  // 关键词不套色块/描边（见 KwStyle 注释），只用「类别色 + 同色划线」
  // （波浪 / 实线 / 点线 / 虚线）表达；必看句的荧光底垫在字下。
  // 加粗只留给人工标注的片段：词表负责「这是什么」，人工负责「值不值得看」，
  // 两件事不重叠，屏幕才不会又花又乱。
  return TextSpan(
    text: text,
    style: base.copyWith(
      color: style.color,
      fontWeight: emphasis ? FontWeight.w600 : base.fontWeight,
      background: sentenceBg == null ? null : _bgPaint(sentenceBg),
      decoration: style.underline != null ? TextDecoration.underline : null,
      decorationColor: style.underline,
      decorationThickness: 1.5,
      decorationStyle: style.dashed
          ? TextDecorationStyle.dashed
          : (style.dotted
              ? TextDecorationStyle.dotted
              : (style.wavy
                  ? TextDecorationStyle.wavy
                  : TextDecorationStyle.solid)),
    ),
  );
}

/// 「必看」句的句首竖条，纯装饰（复制文本时不会带上字符）。
WidgetSpan _coreMarker(bool isDark) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        width: 3,
        height: 12,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isDark ? _coreMarkDark : _coreMarkLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

/// 按「人工标注 + 句子 + 关键词」三层切分并生成富文本 span。
///
/// [baseStyle] 为普通文本样式。三层结构，各司其职：
/// 1. 定档：只有「必看」句铺一层淡荧光底 + 句首竖条；「关注」句不铺底色，
///    只把被人工标注的片段加粗；「一般」句不上任何底色与加粗；
/// 2. 划词：关键词按 6 类着色（只用颜色 + 同色划线，不套色块/描边、不加粗），
///    并与相邻的楼栋、房间号、周次、时间连成一片；
/// 3. 划线：波浪 / 实线 / 点线 / 虚线区分类别。
/// 加粗只表示「人工判断的重点」，词表只表示「这是什么词」，两层不互相叠。
///
/// [tiered] 为 false 时**关掉整层「定档」**——不铺句子底色、不加句首竖条、
/// 不因档位加粗，只做词表着色。用于「本周调整」这类**运行时拼出来的文案**
/// （`「课程名」+ 调整说明`，不是整段原文，无法内联人工标注）：那里的每一行
/// 本身就已是「这周要处理的事」，再叠档位底纹只会让整块列表变成一片花黄。
List<InlineSpan> buildKeywordSpans(
  String content,
  TextStyle baseStyle,
  bool isDark, {
  bool tiered = true,
}) {
  if (content.isEmpty) return const <InlineSpan>[];
  final ann = parseAnnotations(content);
  final text = ann.text;
  if (text.isEmpty) return const <InlineSpan>[];
  final ranges = highlightRanges(text);

  final spans = <InlineSpan>[];
  for (final s in sentenceRanges(text)) {
    final tier = !tiered
        ? ImportanceTier.plain
        : sentenceTierOf(
            text,
            s.start,
            s.end,
            ann.marks,
            ranges,
            annotated: ann.isAnnotated,
          );
    final bg = sentenceBgOf(tier, isDark);
    // 算法定的必看句整句加粗；人工标注的只加粗标注的那几段。
    final boldWhole =
        tiered && !ann.isAnnotated && tier == ImportanceTier.core;
    if (tier == ImportanceTier.core) spans.add(_coreMarker(isDark));

    final hits = ranges
        .where((r) => r.start < s.end && r.end > s.start)
        .toList();
    final mhits = ann.marks
        .where((m) => m.start < s.end && m.end > s.start)
        .toList();

    // 词区间与标注区间的边界一起切，使两层的边界都能落准。
    final cuts = <int>{s.start, s.end};
    for (final r in hits) {
      cuts.add(r.start < s.start ? s.start : (r.start > s.end ? s.end : r.start));
      cuts.add(r.end < s.start ? s.start : (r.end > s.end ? s.end : r.end));
    }
    for (final m in mhits) {
      cuts.add(m.start < s.start ? s.start : (m.start > s.end ? s.end : m.start));
      cuts.add(m.end < s.start ? s.start : (m.end > s.end ? s.end : m.end));
    }
    final points = cuts.toList()..sort();

    for (var i = 0; i + 1 < points.length; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (b <= a) continue;
      KwRange? hit;
      for (final r in hits) {
        if (r.start < b && r.end > a) {
          hit = r;
          break;
        }
      }
      // 只有「必看 / 关注」标注才加粗；「一般」标注是显式压档，不加粗。
      final marked = tiered &&
          mhits.any((m) =>
              m.start < b && m.end > a && m.tier != ImportanceTier.plain);
      final seg = text.substring(a, b);
      if (hit != null) {
        spans.add(_kwSpan(
          seg,
          hit.category,
          baseStyle,
          isDark,
          bg,
          emphasis: marked || boldWhole,
        ));
      } else {
        spans.add(_plainSpan(
          seg,
          baseStyle,
          bg,
          emphasis: marked || boldWhole,
        ));
      }
    }
  }
  return spans;
}
