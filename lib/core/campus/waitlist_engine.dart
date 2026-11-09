import '../../models/campus/json_utils.dart';

// 候补队列的纯函数。
//
// 直接操作服务端的报名行（`Map<String, dynamic>`），这样 Mock 端的
// 状态机与队列维护共用同一套算法，不用担心两边算得不一样。
//
// 队列里只存三样东西：状态、排位、报名时间。递补顺序按报名时间，
// 不按排位——排位只是给人看的展示值，递补时重排不会引起争议。

/// 某活动下仍在队列里的报名（已报 + 候补）。
List<Map<String, dynamic>> activeSignups(
  List<Map<String, dynamic>> all,
  String activityId,
) =>
    [
      for (final row in all)
        if (row['activityId'] == activityId && row['status'] != 'cancelled')
          row,
    ];

int confirmedCount(
  List<Map<String, dynamic>> all,
  String activityId,
) =>
    activeSignups(all, activityId)
        .where((row) => row['status'] == 'confirmed')
        .length;

/// 下一个候补位次。队列为空时从 1 开始。
int nextQueuePosition(
  List<Map<String, dynamic>> all,
  String activityId,
) {
  var max = 0;
  for (final row in activeSignups(all, activityId)) {
    if (row['status'] != 'waitlisted') continue;
    final pos = asInt(row['queuePosition']);
    if (pos > max) max = pos;
  }
  return max + 1;
}

/// 候补里最早报名的那条，没人候补时为 null。
Map<String, dynamic>? firstWaitlisted(
  List<Map<String, dynamic>> all,
  String activityId,
) {
  Map<String, dynamic>? earliest;
  for (final row in activeSignups(all, activityId)) {
    if (row['status'] != 'waitlisted') continue;
    if (earliest == null ||
        asString(row['createdAt']).compareTo(asString(earliest['createdAt'])) <
            0) {
      earliest = row;
    }
  }
  return earliest;
}

/// 按报名时间把候补排位重编成 1..n。
///
/// 有人取消候补后必须调用，否则界面上会出现「候补第 1 位、第 3 位」的空洞。
void renumberWaitlist(
  List<Map<String, dynamic>> all,
  String activityId,
) {
  final waiting = activeSignups(all, activityId)
      .where((row) => row['status'] == 'waitlisted')
      .toList()
    ..sort(
      (a, b) => asString(a['createdAt']).compareTo(asString(b['createdAt'])),
    );
  for (var i = 0; i < waiting.length; i++) {
    waiting[i]['queuePosition'] = i + 1;
  }
}
