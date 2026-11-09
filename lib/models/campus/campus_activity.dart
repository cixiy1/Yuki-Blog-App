import 'campus_scope.dart';
import 'json_utils.dart';

/// 活动生命周期。发布后先 pendingReview，班委/管理员通过才 approved。
enum ActivityStatus {
  pendingReview('待审核'),
  approved('已通过'),
  rejected('已驳回'),
  cancelled('已取消'),
  finished('已结束');

  const ActivityStatus(this.label);

  final String label;

  bool get isPublic => this == approved;
}

/// 报名状态。改名沿用小写连写，与 JSON wire 值一致。
enum SignupStatus {
  confirmed('已报名'),
  waitlisted('候补中'),
  cancelled('已取消');

  const SignupStatus(this.label);

  final String label;
}

/// 一条报名记录。同一用户同一活动只有一条，取消后复用（幂等）。
class ActivitySignup {
  const ActivitySignup({
    required this.id,
    required this.activityId,
    required this.userId,
    required this.userName,
    required this.className,
    required this.status,
    required this.createdAt,
    this.queuePosition,
    this.promotedAt,
  });

  final String id;
  final String activityId;
  final String userId;
  final String userName;
  final String className;
  final SignupStatus status;

  /// 候补位次，1 基。confirmed 时为 null。
  final int? queuePosition;
  final DateTime createdAt;

  /// 从候补被递补成正式报名的时间。
  final DateTime? promotedAt;

  factory ActivitySignup.fromJson(Map<String, dynamic> json) => ActivitySignup(
        id: asString(json['id']),
        activityId: asString(json['activityId']),
        userId: asString(json['userId']),
        userName: asString(json['userName']),
        className: asString(json['className']),
        status: enumByName(
            SignupStatus.values, json['status'], SignupStatus.cancelled),
        queuePosition:
            json['queuePosition'] == null ? null : asInt(json['queuePosition']),
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
        promotedAt: asDate(json['promotedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'activityId': activityId,
        'userId': userId,
        'userName': userName,
        'className': className,
        'status': status.name,
        'queuePosition': queuePosition,
        'createdAt': iso(createdAt),
        'promotedAt': iso(promotedAt),
      };
}

/// 一个可报名的活动。
class CampusActivity {
  const CampusActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.startAt,
    required this.signupDeadline,
    required this.capacity,
    required this.organizerId,
    required this.organizerName,
    required this.createdAt,
    this.endAt,
    this.imageIds = const [],
    this.scope = VisibilityScope.classOnly,
    this.status = ActivityStatus.pendingReview,
    this.rejectReason,
    this.reviewedBy,
    this.reviewedAt,
    this.confirmedCount = 0,
    this.waitlistCount = 0,
    this.mySignup,
    this.isMine = false,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime startAt;
  final DateTime? endAt;
  final DateTime signupDeadline;

  /// 名额上限。满了自动进候补。
  final int capacity;
  final List<String> imageIds;
  final String organizerId;
  final String organizerName;
  final VisibilityScope scope;
  final ActivityStatus status;
  final String? rejectReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  /// 正式报名人数，服务端聚合后返回。
  final int confirmedCount;
  final int waitlistCount;

  /// 当前用户自己的报名记录（服务端按请求者填充）。
  final ActivitySignup? mySignup;
  final bool isMine;

  bool get isFull => confirmedCount >= capacity;
  bool get signupClosed => DateTime.now().isAfter(signupDeadline);
  bool get canSignup =>
      status == ActivityStatus.approved && !isFull && !signupClosed;

  /// 名额占用比例，用于进度条。超过上限时夹到 1。
  double get fillRatio =>
      capacity <= 0 ? 0 : (confirmedCount / capacity).clamp(0.0, 1.0);

  factory CampusActivity.fromJson(Map<String, dynamic> json) => CampusActivity(
        id: asString(json['id']),
        title: asString(json['title']),
        description: asString(json['description']),
        location: asString(json['location']),
        startAt: asDate(json['startAt']) ?? DateTime.now(),
        endAt: asDate(json['endAt']),
        signupDeadline: asDate(json['signupDeadline']) ?? DateTime.now(),
        capacity: asInt(json['capacity'], 1),
        imageIds: asStringList(json['imageIds']),
        organizerId: asString(json['organizerId']),
        organizerName: asString(json['organizerName']),
        scope: enumByName(
            VisibilityScope.values, json['scope'], VisibilityScope.classOnly),
        status: enumByName(
            ActivityStatus.values, json['status'], ActivityStatus.pendingReview),
        rejectReason: asStringOrNull(json['rejectReason']),
        reviewedBy: asStringOrNull(json['reviewedBy']),
        reviewedAt: asDate(json['reviewedAt']),
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
        confirmedCount: asInt(json['confirmedCount']),
        waitlistCount: asInt(json['waitlistCount']),
        mySignup: json['mySignup'] == null
            ? null
            : ActivitySignup.fromJson(asMap(json['mySignup'])),
        isMine: asBool(json['isMine']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'location': location,
        'startAt': iso(startAt),
        'endAt': iso(endAt),
        'signupDeadline': iso(signupDeadline),
        'capacity': capacity,
        'imageIds': imageIds,
        'organizerId': organizerId,
        'organizerName': organizerName,
        'scope': scope.name,
        'status': status.name,
        'rejectReason': rejectReason,
        'reviewedBy': reviewedBy,
        'reviewedAt': iso(reviewedAt),
        'createdAt': iso(createdAt),
        'confirmedCount': confirmedCount,
        'waitlistCount': waitlistCount,
        'mySignup': mySignup?.toJson(),
        'isMine': isMine,
      };

  CampusActivity copyWith({
    int? confirmedCount,
    int? waitlistCount,
    ActivitySignup? mySignup,
    bool clearMySignup = false,
    ActivityStatus? status,
    String? rejectReason,
  }) =>
      CampusActivity(
        id: id,
        title: title,
        description: description,
        location: location,
        startAt: startAt,
        endAt: endAt,
        signupDeadline: signupDeadline,
        capacity: capacity,
        imageIds: imageIds,
        organizerId: organizerId,
        organizerName: organizerName,
        scope: scope,
        status: status ?? this.status,
        rejectReason: rejectReason ?? this.rejectReason,
        reviewedBy: reviewedBy,
        reviewedAt: reviewedAt,
        createdAt: createdAt,
        confirmedCount: confirmedCount ?? this.confirmedCount,
        waitlistCount: waitlistCount ?? this.waitlistCount,
        mySignup: clearMySignup ? null : (mySignup ?? this.mySignup),
        isMine: isMine,
      );
}
