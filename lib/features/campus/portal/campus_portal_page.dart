import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/portal_repository.dart';
import '../../../models/campus/express_task.dart';
import '../../../models/campus/lost_found_post.dart';
import '../../../models/campus/market_item.dart';
import '../messages/message_center_page.dart';
import '../shared/campus_format.dart';
import '../shared/empty_state.dart';
import '../shared/module_launcher.dart';
import '../shared/status_chip.dart';
import 'widgets/feed_preview_section.dart';
import 'widgets/identity_bar.dart';
import 'widgets/module_grid.dart';

/// 校园服务门户。
///
/// 一次 `/portal/summary` 拿齐角标、未读数与三段信息流，
/// 只 `setState` 一次，避免首页刷新时逐块重建。
class CampusPortalPage extends StatefulWidget {
  const CampusPortalPage({super.key, this.services});

  final CampusServices? services;

  @override
  State<CampusPortalPage> createState() => _CampusPortalPageState();
}

class _CampusPortalPageState extends State<CampusPortalPage> {
  PortalSummary _summary = const PortalSummary.empty();
  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  CampusServices get _services => widget.services ?? CampusServices.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 只有第一次进来才铺满屏的 loading，下拉刷新保持内容可见。
    if (!_loadedOnce && mounted) setState(() => _loading = true);
    try {
      final summary = await _services.portal.summary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _loadedOnce = true;
        _error = null;
      });
      _services.unread.value = summary.unread;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _loadedOnce = true;
      });
    }
  }

  Future<void> _openMessages() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MessageCenterPage(services: widget.services),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openModule(CampusModule module) async {
    await openCampusModule(context, module, services: widget.services);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = _services.session.user;

    if (_loading && user != null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingSm,
          AppTheme.spacingMd,
          AppTheme.spacingXl,
        ),
        children: [
          if (user != null)
            IdentityBar(
              user: user,
              unread: _services.unread.value,
              onTapMessages: _openMessages,
            ),
          if (_error != null) ...[
            const SizedBox(height: AppTheme.spacingMd),
            _ErrorHint(message: _error!, onRetry: _load),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          ModuleGrid(counts: _summary.counts, onTap: _openModule),
          FeedPreviewSection<LostFoundPost>(
            title: '最新失物招领',
            items: _summary.latestLostFound,
            emptyText: '还没有人发失物招领',
            emptyIcon: Icons.search_off_rounded,
            onViewAll: () => _openModule(CampusModule.lostFound),
            itemBuilder: (context, post) => _LostFoundRow(post: post),
          ),
          FeedPreviewSection<MarketItem>(
            title: '最新二手',
            items: _summary.latestMarket,
            emptyText: '还没有人在出售闲置',
            emptyIcon: Icons.local_offer_outlined,
            onViewAll: () => _openModule(CampusModule.market),
            itemBuilder: (context, item) => _MarketRow(item: item),
          ),
          FeedPreviewSection<ExpressTask>(
            title: '待接快递',
            items: _summary.pendingExpress,
            emptyText: '暂时没有待接的快递',
            emptyIcon: Icons.inventory_2_outlined,
            onViewAll: () => _openModule(CampusModule.express),
            itemBuilder: (context, task) => _ExpressRow(task: task),
          ),
          if (_summary.latestLostFound.isEmpty &&
              _summary.latestMarket.isEmpty &&
              _summary.pendingExpress.isEmpty &&
              _error == null)
            const EmptyState(
              icon: Icons.public_off_outlined,
              title: '暂时没有可展示的内容',
              message: '发布第一条信息试试',
            ),
        ],
      ),
    );
  }
}

class _LostFoundRow extends StatelessWidget {
  const _LostFoundRow({required this.post});

  final LostFoundPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLost = post.type == LostFoundType.lost;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: 10,
      ),
      child: Row(
        children: [
          StatusChip(
            label: post.type.label,
            color: isLost ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${post.location} · ${formatRelative(post.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({required this.item});

  final MarketItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${item.condition.label} · ${formatRelative(item.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            formatMoney(item.priceCents),
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpressRow extends StatelessWidget {
  const _ExpressRow({required this.task});

  final ExpressTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${task.station} → ${task.deliverTo}',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${formatDeadline(task.deadline)} · ${task.creatorName}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Text(
            formatMoney(task.rewardCents),
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorHint extends StatelessWidget {
  const _ErrorHint({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: AppTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
