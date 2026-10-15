import 'package:yuki_blog_app/models/timetable.dart';

/// 格子状态。
enum CellStatus {
  /// 本周有课。
  on,

  /// 该课程本周不排课。
  off,

  /// 临时新增（会/活动/补课）。
  add,

  /// 本周停课。
  cancel,

  /// 晚自习。
  study,
}

extension CellStatusX on CellStatus {
  String get label => switch (this) {
        CellStatus.on => '有课',
        CellStatus.off => '非本周',
        CellStatus.add => '新增',
        CellStatus.cancel => '停课',
        CellStatus.study => '晚自习',
      };
}

/// 解析后的一条课表条目（课程 / 临时新增 / 晚自习）。
class ResolvedEntry {
  const ResolvedEntry({
    required this.key,
    required this.name,
    required this.short,
    required this.room,
    required this.teacher,
    required this.day,
    required this.slot,
    required this.slotLabel,
    required this.timeText,
    required this.weeks,
    required this.status,
    required this.flag,
    required this.changes,
    required this.selfStudy,
    this.originalRoom,
  });

  /// 全局唯一键（选中态 / 去重用）。
  final String key;

  /// 课程全称。
  final String name;

  /// 格子短名。
  final String short;

  /// 当前教室（换教室后为新教室；可能为空串）。
  final String room;

  /// 换教室前的原教室（仅 room override 时有值）。
  final String? originalRoom;
  final String teacher;

  /// 星期几，1 = 周一 …… 7 = 周日。
  final int day;

  /// 时段行 key（"1-2" / "11" / 自定义如 "15:45"）。
  final String slot;

  /// 自定义时段行的行标（slotLabel）。
  final String? slotLabel;

  /// 展示用时间段文本。
  final String timeText;

  /// 生效周次（晚自习为空）。
  final Set<int> weeks;
  final CellStatus status;

  /// 格子角标文案（改地点 / 停课 / 调课 / 新增 / 自定义 flag）。
  final String flag;

  /// 变动说明列表（详情面板与「本周调整」用）。
  final List<String> changes;
  final bool selfStudy;

  String get cellKey => '$day-$slot';

  /// 同一格内的显示优先级：本周实际发生（有课 / 停课 / 新增）> 晚自习 > 非本周占位。
  ///
  /// 与博客线渲染器 `render()` 里的取格规则一致：一格只显示一条，
  /// 目的是别让「非本周」的旧课卡压在晚自习上（如周三 9-10 的 Java 只在第 4 周）。
  int get cellPriority {
    if (selfStudy) return 1;
    return status == CellStatus.off ? 0 : 2;
  }

  /// 地点展示：有原教室时并列显示「新（原旧）」。
  String get roomDisplay {
    if (originalRoom != null && originalRoom!.isNotEmpty && room.isNotEmpty) {
      return '$room（原$originalRoom）';
    }
    return room;
  }
}

/// 一个时段行（标准行 + 自定义行按起始时间混排）。
class SlotRow {
  const SlotRow({
    required this.key,
    required this.label,
    required this.timeText,
    required this.sortMinutes,
    required this.isCustom,
  });

  final String key;
  final String label;
  final String timeText;
  final int sortMinutes;

  /// 自定义行（临时活动按 time 插入，只在该周出现）。
  final bool isCustom;
}

/// 「本周调整」里的一条。
class ChangeItem {
  const ChangeItem({required this.type, required this.text});

  /// room / move / swap / cancel / add / note / practice。
  final String type;
  final String text;
}

/// 某一周解析完成的完整网格。
class WeekSchedule {
  const WeekSchedule({
    required this.week,
    required this.rows,
    required this.days,
    required this.cells,
    required this.entries,
    required this.changes,
    required this.hasClass,
  });

  final int week;

  /// 按时序排序的时段行。
  final List<SlotRow> rows;

  /// 本周需要展示的星期列（1-5，有周末安排时延展出 6/7）。
  final List<int> days;

  /// "星期-时段" → 条目列表。
  final Map<String, List<ResolvedEntry>> cells;

  /// 全部条目。
  final List<ResolvedEntry> entries;

  /// 本周调整列表。
  final List<ChangeItem> changes;

  /// 本周是否有课（全放假/实践周为 false）。
  final bool hasClass;

  List<ResolvedEntry> entriesAt(int day, String slot) =>
      cells['$day-$slot'] ?? const [];
}

/// 周次解析器：把静态课程数据 + overrides 变成某一周可渲染的网格。
///
/// 规则与博客线渲染器保持一致：
/// - overrides 六种操作（room / move / swap / cancel / add / note）
/// - 晚自习注入（offWeeks / offDays / 晚课占位判定 / cellOverrides）
/// - 自定义时段行按起始时间插入对应位置
/// - 通知按「真实周次」过滤，不随浏览的周次变化
class TimetableResolver {
  TimetableResolver(this.data);

  final TimetableData data;

  /// 当前真实周次（按系统时间与 week1Monday 计算，已夹紧到 1..totalWeeks）。
  int currentWeek([DateTime? now]) {
    final today = now ?? DateTime.now();
    final base = data.meta.week1Monday;
    final todayDate = DateTime(today.year, today.month, today.day);
    final baseDate = DateTime(base.year, base.month, base.day);
    final days = todayDate.difference(baseDate).inDays;
    var week = days ~/ 7 + 1;
    if (week < 1) week = 1;
    if (week > data.meta.totalWeeks) week = data.meta.totalWeeks;
    return week;
  }

  /// 第 [week] 周的周一。
  DateTime mondayOf(int week) =>
      data.meta.week1Monday.add(Duration(days: (week - 1) * 7));

  /// 第 [week] 周的周日。
  DateTime sundayOf(int week) => mondayOf(week).add(const Duration(days: 6));

  /// 按真实周次过滤后的通知列表。
  List<TimetableNotice> visibleNotices(int realWeek) =>
      data.notices.where((n) => n.visibleInWeek(realWeek)).toList();

  /// 解析第 [week] 周的完整网格。
  WeekSchedule resolve(int week) {
    final meta = data.meta;
    final entries = <ResolvedEntry>[];

    // ── 1. 常规课程：应用 room / cancel / move / swap ─────────────
    for (final course in data.courses) {
      var day = course.day;
      var slot = course.slot;
      var status =
          course.weeks.contains(week) ? CellStatus.on : CellStatus.off;
      var room = course.room;
      String? originalRoom;
      var flag = '';
      final changes = <String>[];

      // swap：与另一门课对调时间
      for (final ov in data.overrides) {
        if (ov.type != 'swap' || !ov.weeks.contains(week)) continue;
        if (ov.a != course.id && ov.b != course.id) continue;
        final otherId = ov.a == course.id ? ov.b : ov.a;
        CourseEntry? other;
        for (final c in data.courses) {
          if (c.id == otherId) {
            other = c;
            break;
          }
        }
        if (other == null) continue;
        day = other.day;
        slot = other.slot;
        flag = '对调';
        status = CellStatus.on; // 强制显示
        if (ov.note != null && ov.note!.isNotEmpty) changes.add('调课对调：${ov.note}');
      }

      // room / cancel / move
      for (final ov in data.overrides) {
        if (ov.id != course.id || !ov.weeks.contains(week)) continue;
        switch (ov.type) {
          case 'room':
            originalRoom = course.room;
            room = ov.room ?? course.room;
            flag = '改地点';
            final note = (ov.note != null && ov.note!.isNotEmpty) ? '（${ov.note}）' : '';
            changes.add('上课地点：原 ${course.room} → ${ov.room}$note');
          case 'cancel':
            status = CellStatus.cancel;
            flag = '停课';
            if (ov.note != null && ov.note!.isNotEmpty) changes.add('停课：${ov.note}');
          case 'move':
            day = ov.day ?? day;
            slot = ov.slot ?? slot;
            flag = '调课';
            status = CellStatus.on; // 调课后强制显示
            if (ov.note != null && ov.note!.isNotEmpty) changes.add('调课：${ov.note}');
        }
      }

      entries.add(ResolvedEntry(
        key: course.id,
        name: course.name,
        short: course.short,
        room: room,
        originalRoom: originalRoom,
        teacher: course.teacher,
        day: day,
        slot: slot,
        slotLabel: null,
        timeText: meta.slots[slot]?.time ?? '',
        weeks: course.weeks,
        status: status,
        flag: flag,
        changes: changes,
        selfStudy: false,
      ));
    }

    // ── 2. add：临时新增（可带自定义时段） ────────────────────────
    var addIndex = 0;
    for (final ov in data.overrides) {
      if (ov.type != 'add' || !ov.weeks.contains(week)) continue;
      final slot = ov.slot ?? '';
      final slotInfo = meta.slots[slot];
      final changes = <String>[];
      if (ov.note != null && ov.note!.isNotEmpty) changes.add(ov.note!);
      entries.add(ResolvedEntry(
        key: 'add-$addIndex',
        name: ov.name ?? ov.short ?? '',
        short: ov.short ?? ov.name ?? '',
        room: ov.room ?? '',
        teacher: ov.teacher ?? '',
        day: ov.day ?? 1,
        slot: slot,
        slotLabel: ov.slotLabel,
        timeText: ov.time ?? slotInfo?.time ?? '',
        weeks: ov.weeks,
        status: CellStatus.add,
        flag: ov.flag ?? '新增',
        changes: changes,
        selfStudy: false,
      ));
      addIndex++;
    }

    // ── 3. 晚自习注入 ────────────────────────────────────────────
    final ss = meta.selfStudy;
    if (ss.enabled && !ss.offWeeks.contains(week)) {
      final hasClass = entries
          .any((e) => e.status == CellStatus.on || e.status == CellStatus.add);
      if (hasClass) {
        final daysToCheck = <int>{...ss.days};
        for (final od in ss.onDays) {
          if (od.week == week) daysToCheck.add(od.day);
        }
        final slotInfo = meta.slots[ss.slot];
        for (final d in daysToCheck) {
          if (ss.offDays.contains((week: week, day: d))) continue;
          // 晚课占位判定：生效 / 停课 / 新增都算占了晚上
          final occupied = entries.any((e) =>
              !e.selfStudy &&
              e.day == d &&
              e.slot == ss.slot &&
              (e.status == CellStatus.on ||
                  e.status == CellStatus.add ||
                  e.status == CellStatus.cancel));
          if (occupied) continue;

          final cellOv = ss.cellOverrideFor(week, d);
          final end = cellOv?.end ?? ss.end;
          entries.add(ResolvedEntry(
            key: 'study-$d',
            name: ss.name,
            short: ss.short,
            room: cellOv?.room ?? '',
            teacher: '',
            day: d,
            slot: ss.slot,
            slotLabel: null,
            timeText: slotInfo?.time ?? '',
            weeks: const {},
            status: CellStatus.study,
            flag: '晚自习',
            changes: const [],
            selfStudy: true,
          ));

          // 结束时间晚于默认（20:30）时，额外占 11 节
          final endMinutes = parseMinutes(end);
          final defaultEnd = parseMinutes(ss.end);
          if (endMinutes != null && defaultEnd != null && endMinutes > defaultEnd) {
            entries.add(ResolvedEntry(
              key: 'study-$d-11',
              name: ss.name,
              short: ss.short,
              room: cellOv?.room ?? '',
              teacher: '',
              day: d,
              slot: '11',
              slotLabel: null,
              timeText: '20:30–$end',
              weeks: const {},
              status: CellStatus.study,
              flag: '延长',
              changes: const [],
              selfStudy: true,
            ));
          }
        }
      }
    }

    // ── 4. 时段行：标准行 + 自定义行按起始时间混排 ────────────────
    final rows = <SlotRow>[];
    meta.slots.forEach((key, info) {
      rows.add(SlotRow(
        key: key,
        label: info.label,
        timeText: info.time,
        sortMinutes: info.sortMinutes ?? 0,
        isCustom: false,
      ));
    });
    for (final e in entries) {
      if (e.selfStudy || meta.slots.containsKey(e.slot)) continue;
      if (rows.any((r) => r.key == e.slot)) continue;
      rows.add(SlotRow(
        key: e.slot,
        label: e.slotLabel ?? e.slot,
        timeText: e.timeText,
        sortMinutes: parseSortMinutes(e.timeText) ?? 0,
        isCustom: true,
      ));
    }
    rows.sort((a, b) {
      final byTime = a.sortMinutes.compareTo(b.sortMinutes);
      if (byTime != 0) return byTime;
      // 同起始时间：标准行在前（如自定义 "20:30" 排在 11 节之后）
      if (a.isCustom == b.isCustom) return 0;
      return a.isCustom ? 1 : -1;
    });

    // ── 5. 星期列：课程列 + 本周新增/调入的列 ────────────────────
    final days = <int>{...data.courses.map((c) => c.day)};
    for (final e in entries) {
      days.add(e.day);
    }
    final sortedDays = days.toList()..sort();

    // ── 6. 单元格索引 + 本周调整 ────────────────────────────────
    // 一格只留一条：本周实际发生 > 晚自习 > 非本周占位；同级后者胜出。
    // 与博客线渲染器的取格规则一致，避免「非本周」灰卡与晚自习同格堆叠。
    final cells = <String, List<ResolvedEntry>>{};
    for (final e in entries) {
      final list = cells.putIfAbsent(e.cellKey, () => <ResolvedEntry>[]);
      if (list.isEmpty) {
        list.add(e);
      } else if (e.cellPriority >= list.last.cellPriority) {
        list
          ..clear()
          ..add(e);
      }
    }

    final changes = <ChangeItem>[];
    for (final e in entries) {
      if (e.status == CellStatus.off) continue;
      for (final ch in e.changes) {
        changes.add(ChangeItem(
          type: e.selfStudy
              ? 'study'
              : e.status == CellStatus.add
                  ? 'add'
                  : e.status == CellStatus.cancel
                      ? 'cancel'
                      : 'move',
          text: '「${e.short}」$ch',
        ));
      }
    }
    for (final ov in data.overrides) {
      if (ov.type == 'note' && ov.weeks.contains(week)) {
        changes.add(ChangeItem(type: 'note', text: ov.text ?? ov.note ?? ''));
      }
    }
    for (final p in meta.practice) {
      if (p.weeks.contains(week)) {
        changes.add(ChangeItem(type: 'practice', text: '「${p.name}」${p.note}'));
      }
    }

    final hasClass = entries
        .any((e) => e.status == CellStatus.on || e.status == CellStatus.add);

    return WeekSchedule(
      week: week,
      rows: rows,
      days: sortedDays,
      cells: cells,
      entries: entries,
      changes: changes,
      hasClass: hasClass,
    );
  }
}

/// 周次集合格式化：{4,5,6,7,12,15,16,17,18,19} → "第4-7、12、15-19周"。
String formatWeeks(Set<int> weeks) {
  if (weeks.isEmpty) return '';
  final sorted = weeks.toList()..sort();
  final ranges = <String>[];
  var start = sorted.first;
  var prev = sorted.first;
  for (var i = 1; i < sorted.length; i++) {
    final w = sorted[i];
    if (w == prev + 1) {
      prev = w;
      continue;
    }
    ranges.add(start == prev ? '$start' : '$start-$prev');
    start = w;
    prev = w;
  }
  ranges.add(start == prev ? '$start' : '$start-$prev');
  return '第${ranges.join('、')}周';
}
