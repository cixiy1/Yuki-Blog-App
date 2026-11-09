import 'campus_scope.dart';
import 'json_utils.dart';

/// 快递代取任务状态机：pending → accepted → delivered → completed，
/// cancelled 为终态。
enum ExpressStatus {
  pending('待接单'),
  accepted('已接单'),
  delivered('已送达'),
  completed('已完成'),
  cancelled('已取消');

  const ExpressStatus(this.label);

  final String label;

  bool get isActive => this == pending || this == accepted || this == delivered;
  bool get isFinished => this == completed || this == cancelled;
}

/// 一条代取快递的委托。
class ExpressTask {
  const ExpressTask({
    required this.id,
    required this.station,
    required this.pickupCode,
    required this.deliverTo,
    required this.rewardCents,
    required this.deadline,
    required this.createdAt,
    required this.creatorId,
    required this.creatorName,
    this.note = '',
    this.status = ExpressStatus.pending,
    this.scope = VisibilityScope.classOnly,
    this.courierId,
    this.courierName,
    this.acceptedAt,
    this.deliveredAt,
    this.completedAt,
    this.isMine = false,
    this.isCourier = false,
  });

  final String id;

  /// 驿站名，如「菜鸟驿站（北门）」。
  final String station;

  /// 取件码。服务端只对发布者与接单人返回明文，其余人拿到 `***`。
  final String pickupCode;
  final String deliverTo;
  final String note;
  final int rewardCents;
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final String creatorId;
  final String creatorName;
  final String? courierId;
  final String? courierName;
  final ExpressStatus status;
  final VisibilityScope scope;
  final bool isMine;
  final bool isCourier;

  /// 取件码是否已对当前用户脱敏（列表里展示用）。
  bool get isPickupCodeMasked => pickupCode == kMaskedPickupCode;

  bool get canAccept =>
      status == ExpressStatus.pending && !isMine && courierId == null;

  /// 取件码脱敏占位符，前后端共用同一常量，避免比错。
  static const String kMaskedPickupCode = '***';

  factory ExpressTask.fromJson(Map<String, dynamic> json) => ExpressTask(
        id: asString(json['id']),
        station: asString(json['station']),
        pickupCode: asString(json['pickupCode'], kMaskedPickupCode),
        deliverTo: asString(json['deliverTo']),
        note: asString(json['note']),
        rewardCents: asInt(json['rewardCents']),
        deadline: asDate(json['deadline']) ?? DateTime.now(),
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
        acceptedAt: asDate(json['acceptedAt']),
        deliveredAt: asDate(json['deliveredAt']),
        completedAt: asDate(json['completedAt']),
        creatorId: asString(json['creatorId']),
        creatorName: asString(json['creatorName']),
        courierId: asStringOrNull(json['courierId']),
        courierName: asStringOrNull(json['courierName']),
        status: enumByName(
            ExpressStatus.values, json['status'], ExpressStatus.pending),
        scope: enumByName(
            VisibilityScope.values, json['scope'], VisibilityScope.classOnly),
        isMine: asBool(json['isMine']),
        isCourier: asBool(json['isCourier']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'station': station,
        'pickupCode': pickupCode,
        'deliverTo': deliverTo,
        'note': note,
        'rewardCents': rewardCents,
        'deadline': iso(deadline),
        'createdAt': iso(createdAt),
        'acceptedAt': iso(acceptedAt),
        'deliveredAt': iso(deliveredAt),
        'completedAt': iso(completedAt),
        'creatorId': creatorId,
        'creatorName': creatorName,
        'courierId': courierId,
        'courierName': courierName,
        'status': status.name,
        'scope': scope.name,
        'isMine': isMine,
        'isCourier': isCourier,
      };
}
