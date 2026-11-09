import '../../../models/campus/json_utils.dart';

/// Mock 后端的「数据库」。内存里就是一堆行记录（`List<Map>`），
/// 响应时再转成域模型 —— 不维护第二套实体类，避免双份序列化漂移。
class CampusDb {
  CampusDb({
    this.schemaVersion = currentSchemaVersion,
    Map<String, int>? seq,
    List<Map<String, dynamic>>? users,
    Map<String, dynamic>? sessions,
    List<Map<String, dynamic>>? lostFound,
    List<Map<String, dynamic>>? market,
    List<Map<String, dynamic>>? express,
    List<Map<String, dynamic>>? activities,
    List<Map<String, dynamic>>? signups,
    List<Map<String, dynamic>>? forms,
    List<Map<String, dynamic>>? submissions,
    List<Map<String, dynamic>>? purchases,
    List<Map<String, dynamic>>? reviews,
    List<Map<String, dynamic>>? messages,
    List<Map<String, dynamic>>? media,
  })  : seq = {...?seq},
        users = users ?? [],
        sessions = sessions ?? <String, dynamic>{},
        lostFound = lostFound ?? [],
        market = market ?? [],
        express = express ?? [],
        activities = activities ?? [],
        signups = signups ?? [],
        forms = forms ?? [],
        submissions = submissions ?? [],
        purchases = purchases ?? [],
        reviews = reviews ?? [],
        messages = messages ?? [],
        media = media ?? [];

  /// 结构版本。种子或字段调整时 +1，旧库直接丢弃重播。
  static const int currentSchemaVersion = 1;

  int schemaVersion;
  final Map<String, int> seq;
  final List<Map<String, dynamic>> users;

  /// token → `{userId, expiresAt}`
  final Map<String, dynamic> sessions;

  final List<Map<String, dynamic>> lostFound;
  final List<Map<String, dynamic>> market;
  final List<Map<String, dynamic>> express;
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> signups;
  final List<Map<String, dynamic>> forms;
  final List<Map<String, dynamic>> submissions;
  final List<Map<String, dynamic>> purchases;
  final List<Map<String, dynamic>> reviews;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> media;

  /// 生成下一个 id，形如 `lf_12`。自增游标跟着库一起持久化，
  /// 避免删掉最后一条后 id 撞车。
  String nextId(String prefix) {
    final next = (seq[prefix] ?? 0) + 1;
    seq[prefix] = next;
    return '${prefix}_$next';
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'seq': seq,
        'users': users,
        'sessions': sessions,
        'lostFound': lostFound,
        'market': market,
        'express': express,
        'activities': activities,
        'signups': signups,
        'forms': forms,
        'submissions': submissions,
        'purchases': purchases,
        'reviews': reviews,
        'messages': messages,
        'media': media,
      };

  factory CampusDb.fromJson(Map<String, dynamic> json) => CampusDb(
        schemaVersion: asInt(json['schemaVersion'], 0),
        seq: {
          for (final e in asMap(json['seq']).entries) e.key: asInt(e.value),
        },
        users: asMapList(json['users']),
        sessions: asMap(json['sessions']),
        lostFound: asMapList(json['lostFound']),
        market: asMapList(json['market']),
        express: asMapList(json['express']),
        activities: asMapList(json['activities']),
        signups: asMapList(json['signups']),
        forms: asMapList(json['forms']),
        submissions: asMapList(json['submissions']),
        purchases: asMapList(json['purchases']),
        reviews: asMapList(json['reviews']),
        messages: asMapList(json['messages']),
        media: asMapList(json['media']),
      );
}
