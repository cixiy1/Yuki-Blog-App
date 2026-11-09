import 'json_utils.dart';

/// 成色。
enum ItemCondition {
  newItem('全新'),
  likeNew('几乎全新'),
  good('轻微使用'),
  fair('明显使用');

  const ItemCondition(this.label);

  final String label;
}

/// 二手分类。
enum MarketCategory {
  book('教材书籍'),
  digital('数码电子'),
  daily('生活用品'),
  sports('运动器材'),
  other('其他');

  const MarketCategory(this.label);

  final String label;
}

/// 列表排序方式。
enum MarketSort {
  latest('最新发布'),
  priceAsc('价格从低到高'),
  priceDesc('价格从高到低');

  const MarketSort(this.label);

  final String label;
}

enum MarketStatus {
  onSale('在售'),
  sold('已售出'),
  deleted('已删除');

  const MarketStatus(this.label);

  final String label;
}

/// 一件二手物品。金额一律以「分」为单位存 int，展示时再换算。
class MarketItem {
  const MarketItem({
    required this.id,
    required this.title,
    required this.description,
    required this.contact,
    required this.priceCents,
    required this.condition,
    required this.category,
    required this.sellerId,
    required this.sellerName,
    required this.createdAt,
    this.status = MarketStatus.onSale,
    this.imageIds = const [],
    this.isMine = false,
  });

  final String id;
  final String title;
  final String description;
  final String contact;
  final int priceCents;
  final ItemCondition condition;
  final MarketCategory category;
  final MarketStatus status;
  final List<String> imageIds;
  final String sellerId;
  final String sellerName;
  final DateTime createdAt;
  final bool isMine;

  bool get isOnSale => status == MarketStatus.onSale;

  factory MarketItem.fromJson(Map<String, dynamic> json) => MarketItem(
        id: asString(json['id']),
        title: asString(json['title']),
        description: asString(json['description']),
        contact: asString(json['contact']),
        priceCents: asInt(json['priceCents']),
        condition: enumByName(
            ItemCondition.values, json['condition'], ItemCondition.good),
        category: enumByName(
            MarketCategory.values, json['category'], MarketCategory.other),
        status:
            enumByName(MarketStatus.values, json['status'], MarketStatus.onSale),
        imageIds: asStringList(json['imageIds']),
        sellerId: asString(json['sellerId']),
        sellerName: asString(json['sellerName']),
        createdAt: asDate(json['createdAt']) ?? DateTime.now(),
        isMine: asBool(json['isMine']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'contact': contact,
        'priceCents': priceCents,
        'condition': condition.name,
        'category': category.name,
        'status': status.name,
        'imageIds': imageIds,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'createdAt': iso(createdAt),
        'isMine': isMine,
      };

  MarketItem copyWith({
    String? title,
    String? description,
    String? contact,
    int? priceCents,
    ItemCondition? condition,
    MarketCategory? category,
    MarketStatus? status,
    List<String>? imageIds,
    bool? isMine,
  }) =>
      MarketItem(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        contact: contact ?? this.contact,
        priceCents: priceCents ?? this.priceCents,
        condition: condition ?? this.condition,
        category: category ?? this.category,
        status: status ?? this.status,
        imageIds: imageIds ?? this.imageIds,
        sellerId: sellerId,
        sellerName: sellerName,
        createdAt: createdAt,
        isMine: isMine ?? this.isMine,
      );
}
