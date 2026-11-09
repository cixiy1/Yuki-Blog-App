import 'json_utils.dart';

/// 消息类型。前端按类型选图标与配色，不做业务分支。
enum MessageType {
  activityApproved('活动已通过'),
  activityRejected('活动被驳回'),
  activityPromoted('候补递补成功'),
  expressAccepted('快递被接单'),
  expressDelivered('快递已送达'),
  purchaseAccepted('代买被接单'),
  purchaseCompleted('代买已完成'),
  formReminder('表单催填'),
  creditChanged('信用分变动');

  const MessageType(this.label);

  final String label;
}

/// 消息指向的业务对象，决定点击后跳到哪个详情页。
enum MessageRefType {
  activity,
  express,
  purchase,
  form,
  none,
}

/// 收件箱里的一条消息。按 userId 归属，未读由 `read` 标记。
class AppMessage {
  const AppMessage({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.refType = MessageRefType.none,
    this.refId,
    this.read = false,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final MessageType type;
  final MessageRefType refType;
  final String? refId;
  final bool read;
  final DateTime createdAt;

  factory AppMessage.fromJson(Map<String, dynamic> json) => AppMessage(
        id: asString(json['id']),
        userId: asString(json['userId']),
        title: asString(json['title']),
        body: asString(json['body']),
        type: enumByName(
            MessageType.values, json['type'], MessageType.creditChanged),
        refType:
            enumByName(MessageRefType.values, json['refType'], MessageRefType.none),
        refId: asStringOrNull(json['refId']),
        read: asBool(json['read']),
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'type': type.name,
        'refType': refType.name,
        'refId': refId,
        'read': read,
        'createdAt': iso(createdAt),
      };

  AppMessage copyWith({bool? read}) => AppMessage(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        refType: refType,
        refId: refId,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}
