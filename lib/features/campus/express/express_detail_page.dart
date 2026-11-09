import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/express_task.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';
import '../shared/status_chip.dart';
import '../shared/task_timeline.dart';

/// 快递代取详情：看状态、接单、标记送达、确认完成、取消。
class ExpressDetailPage extends StatefulWidget {
  const ExpressDetailPage({
    super.key,
    required this.services,
    required this.task,
  });

  final CampusServices services;
  final ExpressTask task;

  @override
  State<ExpressDetailPage> createState() => _ExpressDetailPageState();
}

class _ExpressDetailPageState extends State<ExpressDetailPage> {
  late ExpressTask _task = widget.task;
  bool _busy = false;
  bool _changed = false;

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _run(Future<ExpressTask> Function() action, String okText) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _task = updated;
        _changed = true;
        _busy = false;
      });
      _toast(okText);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _task.pickupCode));
    _toast('取件码已复制');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: CampusSubPage(
        title: '代取详情',
        bottomNavigationBar: _actionBar(),
        body: _buildBody(context),
      ),
    );
  }

  Widget? _actionBar() {
    final buttons = <Widget>[];

    if (_task.canAccept) {
      buttons.add(
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            key: const Key('ex-accept'),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.services.express.accept(_task.id),
                      '接单成功，取件码已可见',
                    ),
            icon: const Icon(Icons.directions_run_rounded, size: 18),
            label: const Text('接单'),
          ),
        ),
      );
    }

    if (_task.isCourier && _task.status == ExpressStatus.accepted) {
      buttons.add(
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            key: const Key('ex-deliver'),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.services.express.markDelivered(_task.id),
                      '已标记送达，等对方确认',
                    ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('标记已送达'),
          ),
        ),
      );
    }

    if (_task.isMine && _task.status == ExpressStatus.delivered) {
      buttons.add(
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            key: const Key('ex-complete'),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.services.express.complete(_task.id),
                      '已确认完成',
                    ),
            icon: const Icon(Icons.task_alt_rounded, size: 18),
            label: const Text('确认完成'),
          ),
        ),
      );
    }

    final canCancel = _task.isMine &&
        (_task.status == ExpressStatus.pending ||
            _task.status == ExpressStatus.accepted);
    if (canCancel) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: AppTheme.spacingSm));
      }
      buttons.add(
        Expanded(
          child: OutlinedButton(
            key: const Key('ex-cancel'),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.services.express.cancel(_task.id),
                      '已取消',
                    ),
            child: const Text('取消'),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingSm,
          AppTheme.spacingMd,
          AppTheme.spacingSm,
        ),
        child: Row(children: buttons),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + AppTheme.spacingMd,
        bottom: AppTheme.spacingXl,
        left: AppTheme.spacingMd,
        right: AppTheme.spacingMd,
      ),
      children: [
        Row(
          children: [
            StatusChip(
              label: _task.status.label,
              color: _task.status.isFinished ? scheme.outline : scheme.primary,
            ),
            const SizedBox(width: AppTheme.spacingXs),
            StatusChip(label: _task.scope.label, color: scheme.outline),
            const Spacer(),
            Text(
              formatMoney(_task.rewardCents),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: _task.status.isFinished ? scheme.outline : scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _infoCard(context),
        const SizedBox(height: AppTheme.spacingLg),
        Text(
          '进度',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        TaskTimeline(
          steps: [
            TaskStep(label: '发布委托', at: _task.createdAt),
            TaskStep(label: '有人接单', at: _task.acceptedAt),
            TaskStep(
              label: '送达 ${_task.deliverTo}',
              at: _task.deliveredAt,
            ),
            TaskStep(label: '发布者确认', at: _task.completedAt),
          ],
        ),
        if (_task.status == ExpressStatus.cancelled)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Text(
              '这条委托已取消，不再出现在待接单里。',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ),
        const SizedBox(height: AppTheme.spacingSm),
        _peopleCard(context),
      ],
    );
  }

  Widget _infoCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, '取件地点', _task.station),
          _row(
            context,
            '取件码',
            _task.isPickupCodeMasked ? '接单后可见' : _task.pickupCode,
            key: const Key('ex-pickup-code'),
            trailing: _task.isPickupCodeMasked
                ? null
                : IconButton(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: '复制取件码',
                  ),
          ),
          _row(context, '送达地点', _task.deliverTo),
          _row(context, '最晚送达', formatDateTime(_task.deadline)),
          if (_task.note.isNotEmpty) _row(context, '备注', _task.note),
          const SizedBox(height: 4),
          Text(
            '酬金线下结算，本系统只做记录，不经手资金。',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _peopleCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final courier = _task.courierName;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('发布者', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(_task.creatorName, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.directions_run_rounded,
                  size: 15, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('接单人', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                courier == null || courier.isEmpty ? '还没人接' : courier,
                key: const Key('ex-courier'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Key? key,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              key: key,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
