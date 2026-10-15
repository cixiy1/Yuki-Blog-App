import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
import 'package:yuki_blog_app/features/schedule/widgets/keyword_highlight.dart';
import 'package:yuki_blog_app/models/timetable.dart';

/// 直接用仓库里的真实 JSON 做单测（与博客线数据同源）。
TimetableData _loadData() =>
    TimetableData.fromRawJson(File('assets/data/schedule-2615.json').readAsStringSync());

void main() {
  late TimetableData data;
  late TimetableResolver resolver;

  setUp(() {
    data = _loadData();
    resolver = TimetableResolver(data);
  });

  group('更新历关键词高亮', () {
    test('长词优先：劳动实践 不被截断，类别正确', () {
      final parts =
          splitKeywords('新增劳动实践（W16周二），请交给团支书');
      final kws =
          parts.where((p) => p.category != null).toList();
      expect(kws.map((k) => k.text).join('|'), '新增|劳动实践|团支书');
      expect(kws[0].category, KwCategory.act);
      expect(kws[1].category, KwCategory.evt);
      expect(kws[2].category, KwCategory.role);
    });

    test('无关键词时返回单段原文', () {
      final parts = splitKeywords('一段没有任何重点词的普通描述');
      expect(parts.length, 1);
      expect(parts.single.category, isNull);
    });

    test('划词连片：楼栋房间号前缀与关键词连成一片', () {
      final parts = splitKeywords('G1楼401机房停电');
      final kws = parts.where((p) => p.category != null).toList();
      expect(kws.first.text, 'G1楼401机房');
      expect(kws.first.category, KwCategory.bld);
      expect(kws.last.text, '停电');
      expect(kws.last.category, KwCategory.neg);
    });

    test('划词连片：动词类（act/neg）不连片，负面词不被吞并', () {
      final parts = splitKeywords('第12周改为线上');
      final kws = parts.where((p) => p.category != null).toList();
      expect(kws.single.text, '改为');
      expect(kws.single.category, KwCategory.act);
      expect(parts.first.text, '第12周');
    });

    test('划句：句子区间按 。！？；换行 切分，标点归前句', () {
      final s = sentenceRanges('周五机房停电。改为线上自习！');
      expect(s.length, 2);
      expect(s[0].start, 0);
      expect(s[0].end, 7);
      expect(s[1].start, 7);
      expect(s[1].end, 14);
    });

    test('真实通知：楼栋房间号连片 + 党务词高亮', () {
      // 取班级真实通知原文（第二批入党谈话）
      final parts =
          splitKeywords('1.请准时在14:30到达强能楼502   进行第二批入党谈话');
      final kws = parts.where((p) => p.category != null).toList();
      expect(kws.map((k) => k.text).toList(), ['强能楼502', '入党谈话']);
      expect(kws[0].category, KwCategory.bld);
      expect(kws[1].category, KwCategory.evt);

      final prep = splitKeywords('④请提前准备以下内容')
          .where((p) => p.category != null)
          .single;
      expect(prep.text, '提前');
      expect(prep.category, KwCategory.act);
      final role = splitKeywords('③ 党员的基本条件。')
          .where((p) => p.category != null)
          .single;
      expect(role.text, '党员');
      expect(role.category, KwCategory.role);
    });

    test('富文本：划句底色与高亮词 span 生成', () {
      final spans = buildKeywordSpans(
        '周五机房停电。改为线上自习！',
        const TextStyle(fontSize: 14),
        false,
      );
      // 首句含时空/负面锚点 → 必看，句首多一个竖条 WidgetSpan
      expect(spans.first, isA<WidgetSpan>());
      // 关键词不再套色块药丸，因此全篇只有「必看句首竖条」这一个 WidgetSpan
      expect(spans.whereType<WidgetSpan>().length, 1);
    });
  });

  group('人工标注：读懂内容后手动标重点', () {
    List<ImportanceTier> tiersOf(String raw, {bool? annotated}) {
      final ann = parseAnnotations(raw);
      final rs = highlightRanges(ann.text);
      return [
        for (final s in sentenceRanges(ann.text))
          if (ann.text.substring(s.start, s.end).trim().isNotEmpty)
            sentenceTierOf(ann.text, s.start, s.end, ann.marks, rs,
                annotated: annotated ?? ann.isAnnotated),
      ];
    }

    test('解析三种标注并剥离标记；不成对括号按原文保留', () {
      final a = parseAnnotations('{{必看段}}与[[关注段]]与((一般段))');
      expect(a.text, '必看段与关注段与一般段');
      expect(a.isAnnotated, isTrue);
      expect(a.marks.length, 3);
      expect(a.marks[0].tier, ImportanceTier.core);
      expect(a.marks[1].tier, ImportanceTier.key);
      expect(a.marks[2].tier, ImportanceTier.plain);
      // 区间下标基于剥离后的正文
      expect(a.text.substring(a.marks[1].start, a.marks[1].end), '关注段');

      final b = parseAnnotations('漏写收尾 {{没闭合');
      expect(b.text, '漏写收尾 {{没闭合');
      expect(b.marks, isEmpty);
      expect(b.isAnnotated, isFalse);
    });

    test('整段有标注 → 未标注的句子判为一般，算法不接手', () {
      const raw = '{{10月15日开始}}办体测。\n'
          '本句含10月20日与强能楼502。';
      expect(tiersOf(raw), [ImportanceTier.core, ImportanceTier.plain]);

      // 同一段不标注时，算法会把第二句判成必看（时空锚点齐全）
      const noMark = '10月15日开始办体测。\n本句含10月20日与强能楼502。';
      expect(analyseSentences(noMark).last.tier, ImportanceTier.core);
    });

    test('(( )) 显式压档：整条判为一般，算法不接手', () {
      const raw = '((7-8节标签由「第七节」改为「七八节」（第八节存在）))';
      expect(tiersOf(raw), [ImportanceTier.plain]);
      // 不标注时算法因「改为」判成关注
      expect(
        analyseSentences('7-8节标签由「第七节」改为「七八节」（第八节存在）').single.tier,
        ImportanceTier.key,
      );
    });

    test('无标注文本仍回退算法兜底', () {
      const t = '本句含10月20日与强能楼502。';
      final ann = parseAnnotations(t);
      expect(ann.isAnnotated, isFalse);
      expect(tiersOf(t), [ImportanceTier.core]);
    });

    test('渲染：只给标注片段加粗，(()) 压档条目不铺底色', () {
      final spans = buildKeywordSpans(
        '请在{{明天上午九点}}到教室。',
        const TextStyle(fontSize: 14),
        false,
      );
      // 必看句：句首竖条
      expect(spans.first, isA<WidgetSpan>());
      // 只有被标注的片段加粗
      final bolds = spans
          .whereType<TextSpan>()
          .where((s) => s.style?.fontWeight == FontWeight.w600)
          .map((s) => s.text)
          .toList();
      expect(bolds, ['明天上午九点']);

      final flat = buildKeywordSpans(
        '((新增「数据更新历」面板与「最近更新于」标识))',
        const TextStyle(fontSize: 14),
        false,
      );
      expect(flat.whereType<WidgetSpan>(), isEmpty);
      for (final s in flat) {
        expect(s.style?.background, isNull);
      }
    });

    test('渲染降噪：只有必看句铺底色，关键词不套底色块', () {
      final spans = buildKeywordSpans(
        '{{周五机房停电}}。请提前到强能楼502集合。',
        const TextStyle(fontSize: 14),
        false,
      );
      // 唯一的 WidgetSpan 是必看句的句首竖条（关键词已不套色块药丸）
      expect(spans.first, isA<WidgetSpan>());
      expect(spans.whereType<WidgetSpan>().length, 1);
      // 底色只落在必看句；第二句（无标注 → 一般）不上底色
      final withBg = spans
          .whereType<TextSpan>()
          .where((s) => s.style?.background != null)
          .map((s) => s.text)
          .join();
      expect(withBg, '周五机房停电。');
      expect(spans.last.style?.background, isNull);
    });

    test('真实数据：压档条目全为一般、通知首句必看、有标注条目不漏判', () {
      for (final e in data.meta.changelog) {
        final ann = parseAnnotations(e.content);
        if (ann.marks.any((m) => m.tier == ImportanceTier.plain)) {
          expect(
            tiersOf(e.content).every((t) => t == ImportanceTier.plain),
            isTrue,
            reason: e.content,
          );
        }
      }

      for (final n in data.notices) {
        expect(tiersOf(n.text).first, ImportanceTier.core, reason: n.title);
      }

      var annotated = 0;
      for (final e in data.meta.changelog) {
        final ann = parseAnnotations(e.content);
        if (!ann.isAnnotated) continue;
        annotated++;
        final rs = highlightRanges(ann.text);
        for (final s in sentenceRanges(ann.text)) {
          final covered =
              ann.marks.any((m) => m.start < s.end && m.end > s.start);
          final t = sentenceTierOf(ann.text, s.start, s.end, ann.marks, rs,
              annotated: true);
          if (!covered) {
            expect(t, ImportanceTier.plain, reason: e.content);
          }
        }
      }
      expect(annotated, greaterThan(30));
    });
  });

  group('语义重点度分档', () {
    test('时空锚点句 → 必看；纯明细罗列 → 一般', () {
      const t = '北校区2026级全体学生于10月15日–24日期间参加体质健康测试，'
          '测试地点：北校区田径场看台后面。\n'
          '室内项目：身高体重、立定跳远、坐位体前屈、肺活量、引体向上（男）/仰卧起坐（女）。';
      final s = analyseSentences(t);
      expect(s[0].tier, ImportanceTier.core);
      expect(s[0].has('time'), isTrue);
      expect(s[0].has('place'), isTrue);
      expect(s[1].tier, ImportanceTier.plain);
    });

    test('要求 + 具体动作 → 必看', () {
      const t = '须填写免测申请表并交至本班体育教师处，请尽早办理。';
      final s = analyseSentence(t, 0, t.length);
      expect(s.tier, ImportanceTier.core);
      expect(s.has('require'), isTrue);
      expect(s.has('action'), isTrue);
    });

    test('只有语气词、没有可执行动作 → 关注而非必看', () {
      const t = '晚自习期间请自主规划学习内容、保持安静。';
      final s = analyseSentence(t, 0, t.length);
      expect(s.tier, ImportanceTier.key);
    });

    test('工具自身说明（面板/配色/构建）→ 降权为一般', () {
      const t = '新增「数据更新历」面板与「最近更新于」标识。';
      final s = analyseSentence(t, 0, t.length);
      expect(s.tier, ImportanceTier.plain);
      expect(s.has('meta'), isTrue);
    });

    test('地点正则不误判：室内 / 教育厅 不算地点', () {
      const cases = [
        '2026级室内项目由体育教师自行组织。',
        '室外项目待广东省教育厅抽测通知后另行安排。',
      ];
      for (final t in cases) {
        final s = analyseSentence(t, 0, t.length);
        expect(s.has('place'), isFalse, reason: t);
      }
    });

    test('真实军训服装通知：时间句/地点句/强制购买句全部必看', () {
      const t = '北校区购买时间：10 月 23 日、24 日（周五、周六）每天 8:30—18:00；\n'
          '购买地点：教学楼 118 前空地。\n'
          '注意：军训服装全部新生都要买，申请免训的同学也要买。';
      final coreTexts = analyseSentences(t)
          .where((e) => e.tier == ImportanceTier.core)
          .map((e) => t.substring(e.start, e.end).trim())
          .toList();
      expect(coreTexts, [
        '北校区购买时间：10 月 23 日、24 日（周五、周六）每天 8:30—18:00；',
        '购买地点：教学楼 118 前空地。',
        '注意：军训服装全部新生都要买，申请免训的同学也要买。',
      ]);
    });

    test('必看句渲染出句首标记，一般句不上底色', () {
      final spans = buildKeywordSpans(
        '2026年10月15日14:30到强能楼502开会。\n备注如下。',
        const TextStyle(fontSize: 14),
        false,
      );
      expect(spans.first, isA<WidgetSpan>());
    });
  });

  group('周次计算', () {
    test('2026-10-15 是第 7 周', () {
      expect(resolver.currentWeek(DateTime(2026, 10, 15)), 7);
    });

    test('meta.changelog 解析：git 历史自动生成、最新在前', () {
      // 条目由 gen_changelog.py 从 git 提交历史生成，会持续增长
      expect(data.meta.changelog.length, greaterThan(8));
      expect(data.meta.changelog.first.date, startsWith('2026-10-15'));
      expect(data.meta.changelog.first.content, isNotEmpty);
      expect(data.meta.updated, startsWith('2026-10-15'));
    });

    test('第 1 周周一 = 2026-08-31', () {
      expect(resolver.mondayOf(1), DateTime(2026, 8, 31));
      expect(resolver.sundayOf(1), DateTime(2026, 9, 6));
    });

    test('超出学期范围夹紧到 1..19', () {
      expect(resolver.currentWeek(DateTime(2026, 8, 1)), 1);
      expect(resolver.currentWeek(DateTime(2027, 3, 1)), 19);
    });
  });

  group('第 7 周网格', () {
    late WeekSchedule w7;
    setUp(() => w7 = resolver.resolve(7));

    test('周一至周五五列', () {
      expect(w7.days, [1, 2, 3, 4, 5]);
    });

    test('周一 9-10/11 节 Web 补课，且顶掉晚自习', () {
      final cells = w7.entriesAt(1, '9-10');
      expect(cells.length, 1);
      expect(cells.single.status, CellStatus.add);
      expect(cells.single.name, contains('补课'));
      expect(w7.entriesAt(1, '11').length, 1);
      expect(w7.entries.where((e) => e.selfStudy && e.day == 1), isEmpty);
    });

    test('周三 9-10 排晚自习 强能楼812（与非本周的 c10 堆叠）', () {
      final cells = w7.entriesAt(3, '9-10');
      final study = cells.where((e) => e.selfStudy).toList();
      expect(study.length, 1);
      expect(study.single.room, '强能楼812');
      // c10 仅第 4 周，本周显示为非本周灰格
      expect(cells.where((e) => e.key == 'c10').single.status, CellStatus.off);
    });

    test('周五不排晚自习', () {
      expect(w7.entriesAt(5, '9-10'), isEmpty);
    });

    test('周二 1-2 有 Java 加课（跨周调课目标）', () {
      final cells = w7.entriesAt(2, '1-2');
      expect(cells.length, 1);
      expect(cells.single.status, CellStatus.add);
      expect(cells.single.short, contains('Java'));
    });

    test('换教室：c05→修德楼119（原401），c01→修德楼101（原201）', () {
      final c05 = w7.entries.firstWhere((e) => e.key == 'c05');
      expect(c05.room, '修德楼119');
      expect(c05.originalRoom, '修德楼401');
      expect(c05.roomDisplay, '修德楼119（原修德楼401）');
      final c01 = w7.entries.firstWhere((e) => e.key == 'c01');
      expect(c01.room, '修德楼101');
      expect(c01.originalRoom, '修德楼201');
    });

    test('自定义行 14:00 班委竞选插在 3-4 与 5-6 之间', () {
      final keys = w7.rows.map((r) => r.key).toList();
      expect(keys.indexOf('14:00'), greaterThan(keys.indexOf('3-4')));
      expect(keys.indexOf('14:00'), lessThan(keys.indexOf('5-6')));
      final cell = w7.entriesAt(1, '14:00');
      expect(cell.single.short, contains('班委竞选'));
    });

    test('本周调整含体育停课与多条新增', () {
      expect(w7.changes.any((c) => c.text.contains('停课')), isTrue);
      expect(w7.changes.length, greaterThan(3));
    });
  });

  group('第 5 周（国庆全停）', () {
    test('无课、不排晚自习、大量停课格', () {
      final w5 = resolver.resolve(5);
      expect(w5.hasClass, isFalse);
      expect(w5.entries.where((e) => e.selfStudy), isEmpty);
      expect(
        w5.entries.where((e) => e.status == CellStatus.cancel).length,
        greaterThan(5),
      );
    });
  });

  group('第 4 周', () {
    test('仅周一排晚自习', () {
      final w4 = resolver.resolve(4);
      final study = w4.entries.where((e) => e.selfStudy).toList();
      expect(study.length, 1);
      expect(study.single.day, 1);
    });

    test('周三 9-10 Java（仅第 4 周）生效且换教室 505', () {
      final w4 = resolver.resolve(4);
      final c10 = w4.entries.firstWhere((e) => e.key == 'c10');
      expect(c10.status, CellStatus.on);
      expect(c10.room, '强能楼505');
    });

    test('自定义时段排序：15:45 在 5-6 与 7-8 之间，16:40/21:00 依次靠后', () {
      final w4 = resolver.resolve(4);
      final keys = w4.rows.map((r) => r.key).toList();
      expect(keys.indexOf('15:45'), greaterThan(keys.indexOf('5-6')));
      expect(keys.indexOf('15:45'), lessThan(keys.indexOf('7-8')));
      // 16:40 起始晚于 7-8 节（16:05），排在其后、9-10 节前
      expect(keys.indexOf('16:40'), greaterThan(keys.indexOf('7-8')));
      expect(keys.indexOf('16:40'), lessThan(keys.indexOf('9-10')));
      expect(keys.indexOf('21:00'), greaterThan(keys.indexOf('11')));
    });
  });

  group('第 6 周（补课周一至六）', () {
    test('周六列延展，周三课程挪到周六', () {
      final w6 = resolver.resolve(6);
      expect(w6.days, contains(6));
      final c12 = w6.entries.firstWhere((e) => e.key == 'c12');
      expect(c12.day, 6);
      expect(c12.slot, '7-8');
      expect(c12.flag, '调课');
      expect(w6.entriesAt(3, '7-8').single.short, '返校');
    });
  });

  group('第 13 周（实践周）', () {
    test('offWeeks 不排晚自习，调整里含军事技能', () {
      final w13 = resolver.resolve(13);
      expect(w13.entries.where((e) => e.selfStudy), isEmpty);
      expect(w13.changes.any((c) => c.type == 'practice'), isTrue);
    });
  });

  group('第 18 周', () {
    test('元旦 c14 停课', () {
      final w18 = resolver.resolve(18);
      final c14 = w18.entries.firstWhere((e) => e.key == 'c14');
      expect(c14.status, CellStatus.cancel);
    });
  });

  group('通知按真实周过滤', () {
    test('真实第 7 周三条都显示', () {
      expect(resolver.visibleNotices(7).length, 3);
    });

    test('真实第 13 周全部过期', () {
      expect(resolver.visibleNotices(13), isEmpty);
    });
  });

  group('formatWeeks', () {
    test('连续区间折叠', () {
      expect(formatWeeks({4, 5, 6, 7, 12, 15, 16, 17, 18, 19}), '第4-7、12、15-19周');
    });

    test('单周', () {
      expect(formatWeeks({4}), '第4周');
    });
  });

  group('模型解析', () {
    test('15 门课、42 条 overrides、3 条通知', () {
      expect(data.courses.length, 15);
      expect(data.overrides.length, 42);
      expect(data.notices.length, 3);
    });

    test('weeks 字符串与数组都支持', () {
      expect(parseWeeks('4-12,15-19'),
          {4, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16, 17, 18, 19});
      expect(parseWeeks([4, 5]), {4, 5});
      expect(parseWeeks('12,15'), {12, 15});
    });

    test('meta 关键字段', () {
      expect(data.meta.className, '软件2615');
      expect(data.meta.week1Monday, DateTime(2026, 8, 31));
      expect(data.meta.totalWeeks, 19);
      expect(data.meta.slots.keys, containsAll(['1-2', '7-8', '9-10', '11']));
      expect(data.meta.selfStudy.enabled, isTrue);
      expect(data.meta.practice.single.weeks, {13, 14});
    });
  });
}
