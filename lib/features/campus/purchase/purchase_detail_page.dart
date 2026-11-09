import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/purchase_task.dart';
import '../../../models/campus/review.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';
import '../shared/status_chip.dart';
import '../shared/task_timeline.dart';
import 'widgets/review_sheet.dart';

/// 代买跑腿详情：接单、送达、确认、取消，完成后互评。
class PurchaseDetailPage extends StatefulWidget {
  const PurchaseDetailPage({
    super.key,
    required this.services,
    required this.task,
  });

  final CampusServices services;
  final PurchaseTask task;

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  late PurchaseTask _task = widget.task;
  List<Review> _reviews = const [];
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _loadReviews() async {
    try {
      final list = await widget.services.purchases.reviews(_task.id);
      if (!mounted) return;
      setState(() => _reviews = list);
    } on ApiException {
      // 评价拉不到不影响主流程，静默即可。
    }
  }

  Future<void> _reload() async {
    try {
      final fresh = await widget.services.purchases.detail(_task.id);
      if (!mounted) return;
      setState(() {
        _task = fresh;
        _changed = true;
      });
      await _loadReviews();
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  Future<void> _run(Future<PurchaseTask> Function() action, String okText) async {
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

  Future<void> _review() async {
    final target = _task.isMine ? _task.courierName : _task.creatorName;
    final submitted = await showReviewSheet(
      context,
      services: widget.services,
      taskId: _task.id,
      targetName: target ?? '对方',
    );
    if (submitted && mounted) await _reload();
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
        title: '代买详情',
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
            key: const Key('pu-accept'),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.services.purchases.accept(_task.id),
                      '接单成功，记得线下结算',
                    ),
            icon: const Icon(Icons.directions_run_rounded, size: 18),
            label: const Text('接单'),
          ),
        ),
      );
    }

    if (_task.isCourier && _task.status == PurchaseStatus.accepted) {
      buttons.add(
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            key: const Key('pu-deliver'),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.services.purchases.markDelivered(_task.id),
                      '已标记送达，等对方确认',
                    ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('标记已送达'),
          ),
        ),
      );
    }

    if (_task.isMine && _task.status == PurchaseStatus.delivered) {
      buttons.add(
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            key: const Key('pu-complete'),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.services.purchases.complete(_task.id),
                      '已确认完成，可以互相评价了',
                    ),
            icon: const Icon(Icons.task_alt_rounded, size: 18),
            label: const Text('确认完成'),
          ),
        ),
      );
    }

    if (_task.canReview) {
      buttons.add(
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            key: const Key('pu-review'),
            onPressed: _busy ? null : _review,
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('评价对方'),
          ),
        ),
      );
    }

    final canCancel = _task.isMine &&
        (_task.status == PurchaseStatus.pending ||
            _task.status == PurchaseStatus.accepted);
    if (canCancel) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: AppTheme.spacingSm));
      }
      buttons.add(
        Expanded(
          child: OutlinedButton(
            key: const Key('pu-cancel'),
            onPressed: _busy
                ? null
                : () => _run(
                      () => widget.services.purchases.cancel(_task.id),
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
              color: _task.status == PurchaseStatus.completed
                  ? scheme.outline
                  : scheme.primary,
            ),
            const SizedBox(width: AppTheme.spacingXs),
            StatusChip(label: _task.paymentMethod.label, color: scheme.secondary),
            const Spacer(),
            Text(
              formatMoney(_task.amountCents),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingXs),
        Text(
          _task.title,
          key: const Key('pu-detail-title'),
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        _itemsCard(context),
        const SizedBox(height: AppTheme.spacingSm),
        _routeCard(context),
        if (_task.note.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            '备注：${_task.note}',
            style: theme.textTheme.bodySmall,
          ),
        ],
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
            TaskStep(label: '送达 ${_task.toPlace}', at: _task.deliveredAt),
            TaskStep(label: '发布者确认', at: _task.completedAt),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        _peopleCard(context),
        const SizedBox(height: AppTheme.spacingLg),
        Row(
          children: [
            Text(
              '双方评价',
              style:
                  theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${_reviews.length} 条',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        if (_reviews.isEmpty)
          Text(
            _task.status == PurchaseStatus.completed
                ? '还没有评价，完成后的双方都可以评一次。'
                : '任务完成后，双方可以互相评价。',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          for (final review in _reviews) _reviewTile(context, review),
      ],
    );
  }

  Widget _itemsCard(BuildContext context) {
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
          Row(
            children: [
              Text(
                '要买的东西',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '合计 ${formatMoney(_task.amountCents)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXs),
          for (final item in _task.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${item.name} × ${item.qty}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (item.note != null && item.note!.isNotEmpty)
                    Text(
                      item.note!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _routeCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
              Icon(Icons.trip_origin, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('出发', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(_task.fromPlace, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('送到', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(_task.toPlace, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule_outlined,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('最晚送达', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                formatDateTime(_task.deadline),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _peopleCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
              Text('发布者', style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              Text(_task.creatorName, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(
                '信用 ${_task.creatorCredit}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('接单人', style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              Text(
                _task.courierName?.isNotEmpty == true
                    ? _task.courierName!
                    : '还没人接',
                key: const Key('pu-courier'),
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              if (_task.courierCredit != null)
                Text(
                  '信用 ${_task.courierCredit}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewTile(BuildContext context, Review review) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  review.fromUserName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: AppTheme.spacingXs),
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= review.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 13,
                    color: i <= review.stars
                        ? scheme.tertiary
                        : scheme.outlineVariant,
                  ),
                const Spacer(),
                Text(
                  formatRelative(review.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
            if (review.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  for (final tag in review.tags)
                    StatusChip(label: tag, color: scheme.secondary),
                ],
              ),
            ],
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(review.comment!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
