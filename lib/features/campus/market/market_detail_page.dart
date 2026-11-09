import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/market_item.dart';
import '../shared/campus_format.dart';
import '../shared/campus_gallery.dart';
import '../shared/campus_sub_page.dart';
import '../shared/status_chip.dart';
import 'market_editor_page.dart';

/// 二手物品详情。
///
/// 编辑 / 标记已售 / 删除都会改动列表，退出时统一 `pop(_changed)`。
class MarketDetailPage extends StatefulWidget {
  const MarketDetailPage({
    super.key,
    required this.services,
    required this.item,
  });

  final CampusServices services;
  final MarketItem item;

  @override
  State<MarketDetailPage> createState() => _MarketDetailPageState();
}

class _MarketDetailPageState extends State<MarketDetailPage> {
  late MarketItem _item = widget.item;
  bool _busy = false;
  bool _changed = false;

  bool get _canManage => _item.isMine && _item.isOnSale;

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _reload() async {
    try {
      final fresh = await widget.services.market.detail(_item.id);
      if (!mounted) return;
      setState(() {
        _item = fresh;
        _changed = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MarketEditorPage(
          services: widget.services,
          existing: _item,
        ),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _markSold() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.services.market.markSold(_item.id);
      if (!mounted) return;
      setState(() {
        _item = updated;
        _changed = true;
        _busy = false;
      });
      _toast('已标记为售出，列表里不会再显示');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这件物品？'),
        content: const Text('删除后不会再出现在列表里，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('mk-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.services.market.remove(_item.id);
      if (!mounted) return;
      _changed = true;
      Navigator.of(context).pop(_changed);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    }
  }

  void _copyContact() {
    Clipboard.setData(ClipboardData(text: _item.contact));
    _toast('联系方式已复制');
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
        title: '物品详情',
        actions: [
          if (_item.isMine)
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) {
                if (value == 'delete') _delete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
        ],
        bottomNavigationBar: _ownerBar(),
        body: _buildBody(context),
      ),
    );
  }

  Widget? _ownerBar() {
    if (!_canManage) return null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingSm,
          AppTheme.spacingMd,
          AppTheme.spacingSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('mk-edit'),
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                key: const Key('mk-sold'),
                onPressed: _busy ? null : _markSold,
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: const Text('标记已售出'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        bottom: AppTheme.spacingXl,
      ),
      children: [
        if (_item.imageIds.isNotEmpty)
          CampusGallery(imageIds: _item.imageIds, media: widget.services.media),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatMoney(_item.priceCents),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _item.isOnSale ? scheme.primary : scheme.outline,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  StatusChip(
                    label: _item.status.label,
                    color: _item.isOnSale ? scheme.primary : scheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                _item.title,
                key: const Key('mk-detail-title'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                children: [
                  StatusChip(label: _item.condition.label, color: scheme.tertiary),
                  const SizedBox(width: AppTheme.spacingXs),
                  StatusChip(label: _item.category.label, color: scheme.secondary),
                  const Spacer(),
                  Text(
                    formatRelative(_item.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                _item.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              _contactCard(context),
              const SizedBox(height: AppTheme.spacingMd),
              _sellerRow(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: _copyContact,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 18, color: scheme.primary),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '联系卖家',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _item.contact,
                      key: const Key('mk-detail-contact'),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy_rounded, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sellerRow(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final letter = _item.sellerName.isEmpty
        ? '?'
        : String.fromCharCode(_item.sellerName.runes.first);

    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: scheme.primary.withValues(alpha: 0.15),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSm),
        Text(_item.sellerName, style: theme.textTheme.bodySmall),
        if (_item.isMine) ...[
          const SizedBox(width: AppTheme.spacingXs),
          Text(
            '（我发布的）',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
