import 'json_utils.dart';
import 'review.dart';

/// 代买物品清单里的一项。
class PurchaseItem {
  const PurchaseItem({required this.name, this.qty = 1, this.note});

  final String name;
  final int qty;
  final String? note;

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        name: asString(json['name']),
        qty: asInt(json['qty'], 1),
        note: asStringOrNull(json['note']),
      );

  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'note': note};
}

/// 收款方式。不做支付，只记录线下怎么结。
enum PaymentMethod {
  wechat('微信'),
  alipay('支付宝'),
  cash('现金');

  const PaymentMethod(this.label);

  final String label;
}

/// 跑腿任务状态机，与快递代取一致。
enum PurchaseStatus {
  pending('待接单'),
  accepted('已接单'),
  delivered('已送达'),
  completed('已完成'),
  cancelled('已取消');

  const PurchaseStatus(this.label);

  final String label;

  bool get isActive => this == pending || this == accepted || this == delivered;
}

/// 一条代买 / 跑腿委托。金额单位为分，界面标注「线下结算」。
class PurchaseTask {
  const PurchaseTask({
    required this.id,
    required this.title,
    required this.fromPlace,
    required this.toPlace,
    required this.items,
    required this.amountCents,
    required this.paymentMethod,
    required this.deadline,
    required this.createdAt,
    required this.creatorId,
    required this.creatorName,
    this.note = '',
    this.status = PurchaseStatus.pending,
    this.courierId,
    this.courierName,
    this.acceptedAt,
    this.deliveredAt,
    this.completedAt,
    this.creatorCredit = 70,
    this.courierCredit,
    this.myReview,
    this.isMine = false,
    this.isCourier = false,
    this.reviewedByMe = false,
  });

  final String id;
  final String title;
  final String note;
  final String fromPlace;
  final String toPlace;
  final List<PurchaseItem> items;
  final int amountCents;
  final PaymentMethod paymentMethod;
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final String creatorId;
  final String creatorName;
  final String? courierId;
  final String? courierName;
  final PurchaseStatus status;
  final int creatorCredit;
  final int? courierCredit;

  /// 当前用户对这笔单的评价（已评过则非空）。
  final Review? myReview;
  final bool isMine;
  final bool isCourier;
  final bool reviewedByMe;

  bool get canAccept =>
      status == PurchaseStatus.pending && !isMine && courierId == null;

  bool get canReview => status == PurchaseStatus.completed && !reviewedByMe;

  factory PurchaseTask.fromJson(Map<String, dynamic> json) => PurchaseTask(
        id: asString(json['id']),
        title: asString(json['title']),
        note: asString(json['note']),
        fromPlace: asString(json['fromPlace']),
        toPlace: asString(json['toPlace']),
        items: [
          for (final row in asMapList(json['items']))
            PurchaseItem.fromJson(row),
        ],
        amountCents: asInt(json['amountCents']),
        paymentMethod: enumByName(
            PaymentMethod.values, json['paymentMethod'], PaymentMethod.wechat),
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
            PurchaseStatus.values, json['status'], PurchaseStatus.pending),
        creatorCredit: asInt(json['creatorCredit'], 70),
        courierCredit:
            json['courierCredit'] == null ? null : asInt(json['courierCredit']),
        myReview: json['myReview'] == null
            ? null
            : Review.fromJson(asMap(json['myReview'])),
        isMine: asBool(json['isMine']),
        isCourier: asBool(json['isCourier']),
        reviewedByMe: asBool(json['reviewedByMe']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'fromPlace': fromPlace,
        'toPlace': toPlace,
        'items': [for (final i in items) i.toJson()],
        'amountCents': amountCents,
        'paymentMethod': paymentMethod.name,
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
        'creatorCredit': creatorCredit,
        'courierCredit': courierCredit,
        'myReview': myReview?.toJson(),
        'isMine': isMine,
        'isCourier': isCourier,
        'reviewedByMe': reviewedByMe,
      };
}
