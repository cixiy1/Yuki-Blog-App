import 'json_utils.dart';

/// 预置评价标签。存字面量，改文案不影响统计（标签本来就只是展示）。
class ReviewTags {
  ReviewTags._();

  static const List<String> positive = [
    '准时',
    '态度好',
    '包装完好',
    '沟通顺畅',
    '有耐心',
    '与描述一致',
  ];

  static const List<String> negative = [
    '迟到',
    '沟通不畅',
    '与描述不符',
    '私自加价',
  ];

  static List<String> get all => [...positive, ...negative];
}

/// 一次单向评价：from → to。同一任务同一评价人只能有一条。
class Review {
  const Review({
    required this.id,
    required this.taskId,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    required this.stars,
    required this.createdAt,
    this.taskType = 'purchase',
    this.tags = const [],
    this.comment,
  });

  final String id;
  final String taskId;

  /// 目前恒为 `purchase`，留字段为将来评价其他业务做准备。
  final String taskType;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;

  /// 1-5 星。
  final int stars;
  final List<String> tags;
  final String? comment;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: asString(json['id']),
        taskId: asString(json['taskId']),
        taskType: asString(json['taskType'], 'purchase'),
        fromUserId: asString(json['fromUserId']),
        fromUserName: asString(json['fromUserName']),
        toUserId: asString(json['toUserId']),
        toUserName: asString(json['toUserName']),
        stars: asInt(json['stars'], 5).clamp(1, 5),
        tags: asStringList(json['tags']),
        comment: asStringOrNull(json['comment']),
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'taskType': taskType,
        'fromUserId': fromUserId,
        'fromUserName': fromUserName,
        'toUserId': toUserId,
        'toUserName': toUserName,
        'stars': stars,
        'tags': tags,
        'comment': comment,
        'createdAt': iso(createdAt),
      };
}
