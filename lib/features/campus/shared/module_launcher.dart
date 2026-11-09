import 'package:flutter/material.dart';

import '../../../core/campus/campus_services.dart';
import '../lostfound/lost_found_list_page.dart';

/// 六大模块。
enum CampusModule {
  lostFound('失物招领', Icons.search_rounded, 'lostFound'),
  market('二手闲置', Icons.local_offer_outlined, 'market'),
  express('快递代取', Icons.inventory_2_outlined, 'express'),
  activity('活动报名', Icons.event_available_outlined, 'activity'),
  form('表单收集', Icons.assignment_outlined, 'forms'),
  purchase('代买跑腿', Icons.delivery_dining_outlined, 'purchase');

  const CampusModule(this.label, this.icon, this.countKey);

  final String label;
  final IconData icon;

  /// 对应门户 `counts` 里的 key。
  final String countKey;
}

/// 点模块卡片时的统一出口。
///
/// 各模块的列表页在后续批次陆续接入，没接的先用 SnackBar 兜住，
/// 免得点了没反应。
Future<void> openCampusModule(
  BuildContext context,
  CampusModule module, {
  CampusServices? services,
}) async {
  final subject = services ?? CampusServices.instance;

  switch (module) {
    case CampusModule.lostFound:
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => LostFoundListPage(services: subject),
        ),
      );
    case CampusModule.market:
    case CampusModule.express:
    case CampusModule.activity:
    case CampusModule.form:
    case CampusModule.purchase:
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${module.label}正在接入'),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
