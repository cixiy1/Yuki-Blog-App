import 'json_utils.dart';

/// 丢失 / 拾获。
enum LostFoundType {
  lost('寻物'),
  found('招领');

  const LostFoundType(this.label);

  final String label;
}

/// 帖子状态。删除走软删，保留记录便于审计。
enum PostStatus {
  open('进行中'),
  closed('已完成'),
  deleted('已删除');

  const PostStatus(this.label);

  final String label;
}

/// 一条失物招领。默认全校可见，因此携带作者班级用于展示。
class LostFoundPost {
  const LostFoundPost({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.contact,
    required this.type,
    required this.occurredAt,
    required this.createdAt,
    required this.authorId,
    required this.authorName,
    required this.authorClassName,
    this.imageIds = const [],
    this.status = PostStatus.open,
    this.isMine = false,
  });

  final String id;
  final String title;
  final String description;

  /// 丢失/拾获地点，自由文本（如「三饭二楼」「图书馆三楼」）。
  final String location;

  /// 联系方式，手机号或微信号，原样展示。
  final String contact;
  final LostFoundType type;

  /// 事情发生时间（丢了 / 捡到的时间），与发布时间区分。
  final DateTime occurredAt;
  final DateTime createdAt;
  final List<String> imageIds;
  final String authorId;
  final String authorName;
  final String authorClassName;
  final PostStatus status;

  /// 由服务端按请求者身份算出，不入库。
  final bool isMine;

  bool get isOpen => status == PostStatus.open;

  factory LostFoundPost.fromJson(Map<String, dynamic> json) => LostFoundPost(
        id: asString(json['id']),
        title: asString(json['title']),
        description: asString(json['description']),
        location: asString(json['location']),
        contact: asString(json['contact']),
        type: enumByName(LostFoundType.values, json['type'], LostFoundType.lost),
        occurredAt: asDate(json['occurredAt']) ?? DateTime.now(),
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
        imageIds: asStringList(json['imageIds']),
        authorId: asString(json['authorId']),
        authorName: asString(json['authorName']),
        authorClassName: asString(json['authorClassName']),
        status: enumByName(PostStatus.values, json['status'], PostStatus.open),
        isMine: asBool(json['isMine']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'contact': contact,
        'type': type.name,
        'occurredAt': iso(occurredAt),
        'createdAt': iso(createdAt),
        'imageIds': imageIds,
        'authorId': authorId,
        'authorName': authorName,
        'authorClassName': authorClassName,
        'status': status.name,
        'isMine': isMine,
      };

  LostFoundPost copyWith({
    String? title,
    String? description,
    String? location,
    String? contact,
    LostFoundType? type,
    DateTime? occurredAt,
    List<String>? imageIds,
    PostStatus? status,
    bool? isMine,
  }) =>
      LostFoundPost(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        location: location ?? this.location,
        contact: contact ?? this.contact,
        type: type ?? this.type,
        occurredAt: occurredAt ?? this.occurredAt,
        createdAt: createdAt,
        imageIds: imageIds ?? this.imageIds,
        authorId: authorId,
        authorName: authorName,
        authorClassName: authorClassName,
        status: status ?? this.status,
        isMine: isMine ?? this.isMine,
      );
}
