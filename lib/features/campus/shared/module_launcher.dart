import 'package:flutter/material.dart';

import '../../../core/campus/campus_services.dart';

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
/// 各模块的列表页在后续批次陆续接入，这里先兜住「还没做好」的情况，
/// 免得点了没反应。
Future<void> openCampusModule(
  BuildContext context,
  CampusModule module, {
  CampusServices? services,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  switch (module) {
    case CampusModule.lostFound:
    case CampusModule.market:
    case CampusModule.express:
    case CampusModule.activity:
    case CampusModule.form:
    case CampusModule.purchase:
      messenger.showSnackBar(
        SnackBar(
          content: Text('${module.label}正在接入'),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
