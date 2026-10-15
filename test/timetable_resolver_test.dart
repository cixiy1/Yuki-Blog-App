import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuki_blog_app/core/timetable_resolver.dart';
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

  group('周次计算', () {
    test('2026-10-15 是第 7 周', () {
      expect(resolver.currentWeek(DateTime(2026, 10, 15)), 7);
    });

    test('meta.changelog 解析：8 条、最新在前', () {
      expect(data.meta.changelog.length, 8);
      expect(data.meta.changelog.first.date, '2026-10-15');
      expect(data.meta.changelog.first.content, contains('团支书'));
      expect(data.meta.updated, '2026-10-15');
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
