/// 软件2615 动态课表数据模型。
///
/// 与博客线数据 `schedule-2615.json` 的结构一一对应：
/// - `meta`：班级信息、周次基准（week1Monday）、节次时段、晚自习配置、实践周
/// - `courses`：15 门常规课程
/// - `overrides`：调整数组（room / move / swap / cancel / add / note 六种）
/// - `notices`：通知区（与课表网格解耦）
library;

import 'dart:convert';

/// 把周次字段解析成集合。
///
/// 支持两种写法：
/// - 字符串：`"4-12,15-19"`
/// - 数组：`[4, 5]` 或混合 `["4-6", 8]`
Set<int> parseWeeks(Object? value) {
  if (value == null) return const {};
  if (value is int) return {value};
  if (value is List) {
    final result = <int>{};
    for (final item in value) {
      result.addAll(parseWeeks(item));
    }
    return result;
  }
  if (value is String) return _parseWeeksString(value);
  return const {};
}

Set<int> _parseWeeksString(String raw) {
  final result = <int>{};
  for (final part in raw.split(',')) {
    final text = part.trim();
    if (text.isEmpty) continue;
    final range = text.split('-');
    if (range.length == 2) {
      final from = int.tryParse(range[0].trim());
      final to = int.tryParse(range[1].trim());
      if (from != null && to != null && from <= to) {
        result.addAll(List.generate(to - from + 1, (i) => from + i));
      }
    } else {
      final week = int.tryParse(text);
      if (week != null) result.add(week);
    }
  }
  return result;
}

/// "HH:MM" → 当日分钟数；无法解析返回 null。
int? parseMinutes(String? value) {
  if (value == null) return null;
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}

/// 取时间段文本里的第一个 "HH:MM" 作为排序键（如 "16:40–17:10" → 16:40）。
int? parseSortMinutes(String? value) => parseMinutes(value);

/// 单个节次时段（meta.periods）。
class PeriodInfo {
  const PeriodInfo({
    required this.name,
    required this.start,
    required this.end,
  });

  final String name;
  final String start;
  final String end;

  /// 第八节等空白节次：start/end 为空。
  bool get isBlank => start.isEmpty || end.isEmpty;

  factory PeriodInfo.fromJson(Map<String, dynamic> json) => PeriodInfo(
        name: json['name'] as String? ?? '',
        start: json['start'] as String? ?? '',
        end: json['end'] as String? ?? '',
      );
}

/// 合并时段行（meta.slots，如 "1-2" / "7-8" / "11"）。
class SlotInfo {
  const SlotInfo({
    required this.key,
    required this.label,
    required this.time,
    this.note = '',
  });

  final String key;
  final String label;
  final String time;
  final String note;

  /// 行排序键：取 time 里第一个 HH:MM。
  int? get sortMinutes => parseSortMinutes(time);

  factory SlotInfo.fromJson(String key, Map<String, dynamic> json) => SlotInfo(
        key: key,
        label: json['label'] as String? ?? key,
        time: json['time'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}

/// 晚自习按「周-星期」的教室 / 结束时间覆盖。
class SelfStudyCellOverride {
  const SelfStudyCellOverride({this.room, this.end});

  final String? room;
  final String? end;

  factory SelfStudyCellOverride.fromJson(Map<String, dynamic> json) =>
      SelfStudyCellOverride(
        room: json['room'] as String?,
        end: json['end'] as String?,
      );
}

/// 晚自习配置（meta.selfStudy）。
class SelfStudyConfig {
  const SelfStudyConfig({
    required this.enabled,
    required this.days,
    required this.onDays,
    required this.slot,
    required this.start,
    required this.end,
    required this.name,
    required this.short,
    required this.cellOverrides,
    required this.offWeeks,
    required this.offDays,
  });

  final bool enabled;
  final Set<int> days;
  final Set<({int week, int day})> onDays;
  final String slot;
  final String start;
  final String end;
  final String name;
  final String short;
  final Map<String, SelfStudyCellOverride> cellOverrides;
  final Set<int> offWeeks;
  final Set<({int week, int day})> offDays;

  SelfStudyCellOverride? cellOverrideFor(int week, int day) =>
      cellOverrides['$week-$day'];

  factory SelfStudyConfig.fromJson(Map<String, dynamic> json) {
    final cellOverrides = <String, SelfStudyCellOverride>{};
    final rawCells = json['cellOverrides'] as Map<String, dynamic>? ?? {};
    rawCells.forEach((key, value) {
      cellOverrides[key] =
          SelfStudyCellOverride.fromJson(value as Map<String, dynamic>);
    });
    return SelfStudyConfig(
      enabled: json['enabled'] as bool? ?? false,
      days: parseWeeks(json['days']),
      onDays: _parseWeekDayPairs(json['onDays']),
      slot: json['slot'] as String? ?? '9-10',
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
      name: json['name'] as String? ?? '晚自习',
      short: json['short'] as String? ?? '晚自习',
      cellOverrides: cellOverrides,
      offWeeks: parseWeeks(json['offWeeks']),
      offDays: _parseWeekDayPairs(json['offDays']),
    );
  }

  static Set<({int week, int day})> _parseWeekDayPairs(Object? value) {
    final result = <({int week, int day})>{};
    if (value is! List) return result;
    for (final item in value) {
      if (item is List && item.length == 2) {
        final week = item[0] as int?;
        final day = item[1] as int?;
        if (week != null && day != null) {
          result.add((week: week, day: day));
        }
      }
    }
    return result;
  }
}

/// 整周实践（meta.practice，如军事技能 13-14 周）。
class PracticeWeek {
  const PracticeWeek({
    required this.name,
    required this.teacher,
    required this.weeks,
    required this.note,
  });

  final String name;
  final String teacher;
  final Set<int> weeks;
  final String note;

  factory PracticeWeek.fromJson(Map<String, dynamic> json) => PracticeWeek(
        name: json['name'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        weeks: parseWeeks(json['weeks']),
        note: json['note'] as String? ?? '',
      );
}

/// 课表元信息（meta）。
class TimetableMeta {
  const TimetableMeta({
    required this.className,
    required this.campus,
    required this.term,
    required this.week1Monday,
    required this.totalWeeks,
    required this.updated,
    required this.periods,
    required this.slots,
    required this.selfStudy,
    required this.practice,
  });

  final String className;
  final String campus;
  final String term;

  /// 第 1 周周一日期，全学年周次计算的基准（错一天全班都错）。
  final DateTime week1Monday;
  final int totalWeeks;
  final String updated;
  final List<PeriodInfo> periods;
  final Map<String, SlotInfo> slots;
  final SelfStudyConfig selfStudy;
  final List<PracticeWeek> practice;

  factory TimetableMeta.fromJson(Map<String, dynamic> json) {
    final slots = <String, SlotInfo>{};
    final rawSlots = json['slots'] as Map<String, dynamic>? ?? {};
    rawSlots.forEach((key, value) {
      slots[key] = SlotInfo.fromJson(key, value as Map<String, dynamic>);
    });
    return TimetableMeta(
      className: json['className'] as String? ?? '',
      campus: json['campus'] as String? ?? '',
      term: json['term'] as String? ?? '',
      week1Monday: DateTime.parse(json['week1Monday'] as String),
      totalWeeks: json['totalWeeks'] as int? ?? 19,
      updated: json['updated'] as String? ?? '',
      periods: (json['periods'] as List<dynamic>? ?? [])
          .map((e) => PeriodInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      slots: slots,
      selfStudy: SelfStudyConfig.fromJson(
          json['selfStudy'] as Map<String, dynamic>? ?? const {}),
      practice: (json['practice'] as List<dynamic>? ?? [])
          .map((e) => PracticeWeek.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 一门常规课程（courses 数组元素）。
class CourseEntry {
  const CourseEntry({
    required this.id,
    required this.day,
    required this.slot,
    required this.name,
    required this.short,
    required this.room,
    required this.teacher,
    required this.weeks,
  });

  final String id;

  /// 星期几，1 = 周一 …… 7 = 周日。
  final int day;

  /// 时段行 key，如 "1-2" / "7-8" / "9-10" / "11"。
  final String slot;
  final String name;

  /// 格子里的短名（如 "Java"）；数据缺失时回退用 [name]。
  final String short;
  final String room;
  final String teacher;

  /// 开课周次集合。
  final Set<int> weeks;

  factory CourseEntry.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return CourseEntry(
      id: json['id'] as String? ?? '',
      day: json['day'] as int? ?? 1,
      slot: json['slot'] as String? ?? '',
      name: name,
      short: (json['short'] as String?) ?? name,
      room: json['room'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      weeks: parseWeeks(json['weeks']),
    );
  }
}

/// 一条课表调整（overrides 数组元素）。
///
/// type 取值：
/// - `room`：换教室（长期或指定周）
/// - `move`：同一周内改时间/地点，并强制显示
/// - `swap`：两门课对调时间
/// - `cancel`：停课
/// - `add`：临时新增（课/会/活动），可带自定义时段 time + slotLabel + flag
/// - `note`：纯提示，不占格子
class ScheduleOverride {
  const ScheduleOverride({
    required this.weeks,
    required this.type,
    this.id,
    this.day,
    this.slot,
    this.room,
    this.name,
    this.short,
    this.teacher,
    this.note,
    this.flag,
    this.text,
    this.time,
    this.slotLabel,
    this.a,
    this.b,
  });

  final Set<int> weeks;
  final String type;
  final String? id;
  final int? day;
  final String? slot;
  final String? room;
  final String? name;
  final String? short;
  final String? teacher;
  final String? note;

  /// add 类可覆盖格子角标文案（如 "交资料"）。
  final String? flag;
  final String? text;
  final String? time;
  final String? slotLabel;

  /// swap 类型：对调双方课程 id。
  final String? a;
  final String? b;

  /// 展示名：name → short → 空。
  String get displayName => name ?? short ?? '';

  factory ScheduleOverride.fromJson(Map<String, dynamic> json) =>
      ScheduleOverride(
        weeks: parseWeeks(json['weeks']),
        type: json['type'] as String? ?? '',
        id: json['id'] as String?,
        day: json['day'] as int?,
        slot: json['slot'] as String?,
        room: json['room'] as String?,
        name: json['name'] as String?,
        short: json['short'] as String?,
        teacher: json['teacher'] as String?,
        note: json['note'] as String?,
        flag: json['flag'] as String?,
        text: json['text'] as String?,
        time: json['time'] as String?,
        slotLabel: json['slotLabel'] as String?,
        a: json['a'] as String?,
        b: json['b'] as String?,
      );
}

/// 一条通知（notices 数组元素）。
///
/// [weeks] 为 null 表示常驻；否则只在指定真实周次显示。
class TimetableNotice {
  const TimetableNotice({
    required this.date,
    required this.title,
    required this.text,
    this.weeks,
  });

  /// 展示用日期字符串（如 "10/15–10/24"），原样显示。
  final String date;
  final String title;
  final String text;
  final Set<int>? weeks;

  bool visibleInWeek(int realWeek) => weeks == null || weeks!.contains(realWeek);

  factory TimetableNotice.fromJson(Map<String, dynamic> json) => TimetableNotice(
        date: json['date'] as String? ?? '',
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        weeks: json['weeks'] == null ? null : parseWeeks(json['weeks']),
      );
}

/// 课表全量数据（schedule-2615.json 根对象）。
class TimetableData {
  const TimetableData({
    required this.meta,
    required this.courses,
    required this.overrides,
    required this.notices,
  });

  final TimetableMeta meta;
  final List<CourseEntry> courses;
  final List<ScheduleOverride> overrides;
  final List<TimetableNotice> notices;

  factory TimetableData.fromJson(Map<String, dynamic> json) => TimetableData(
        meta: TimetableMeta.fromJson(json['meta'] as Map<String, dynamic>),
        courses: (json['courses'] as List<dynamic>? ?? [])
            .map((e) => CourseEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        overrides: (json['overrides'] as List<dynamic>? ?? [])
            .map((e) => ScheduleOverride.fromJson(e as Map<String, dynamic>))
            .toList(),
        notices: (json['notices'] as List<dynamic>? ?? [])
            .map((e) => TimetableNotice.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static TimetableData fromRawJson(String raw) =>
      TimetableData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
