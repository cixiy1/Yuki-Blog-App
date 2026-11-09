import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/lost_found_post.dart';
import '../shared/campus_format.dart';
import '../shared/campus_gallery.dart';
import '../shared/campus_sub_page.dart';
import '../shared/status_chip.dart';
import 'lost_found_editor_page.dart';

/// 失物招领详情。
///
/// 编辑 / 标记完成 / 删除都会改变列表内容，所以退出时统一
/// `pop(_changed)`，由列表页决定要不要重拉。
class LostFoundDetailPage extends StatefulWidget {
  const LostFoundDetailPage({
    super.key,
    required this.services,
    required this.post,
  });

  final CampusServices services;
  final LostFoundPost post;

  @override
  State<LostFoundDetailPage> createState() => _LostFoundDetailPageState();
}

class _LostFoundDetailPageState extends State<LostFoundDetailPage> {
  late LostFoundPost _post = widget.post;
  bool _busy = false;
  bool _changed = false;

  bool get _canEdit => _post.isMine && _post.isOpen;

  /// 招领类说「已归还」，寻物类说「已找回」——按钮文案跟着类型走。
  String get _closeLabel =>
      _post.type == LostFoundType.found ? '标记已归还' : '标记已找回';

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _reload() async {
    try {
      final fresh = await widget.services.lostFound.detail(_post.id);
      if (!mounted) return;
      setState(() {
        _post = fresh;
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
        builder: (_) => LostFoundEditorPage(
          services: widget.services,
          existing: _post,
        ),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _close() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.services.lostFound.close(_post.id);
      if (!mounted) return;
      setState(() {
        _post = updated;
        _changed = true;
        _busy = false;
      });
      _toast('已标记完成，列表里不会再显示');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('操作失败：$e');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条信息？'),
        content: const Text('删除后不会再出现在列表里，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('lf-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await widget.services.lostFound.remove(_post.id);
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
    Clipboard.setData(ClipboardData(text: _post.contact));
    _toast('联系方式已复制');
  }

  @override
  Widget build(BuildContext context) {
    // 返回键与手势都要带上「有没有改过」，所以拦截一次 pop 再自己回传结果。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed);
      },
      child: CampusSubPage(
        title: _post.type.label,
        actions: [
          if (_post.isMine)
            PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) {
                if (value == 'delete') _delete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('删除'),
                ),
              ],
            ),
        ],
        bottomNavigationBar: _ownerBar(),
        body: _buildBody(context),
      ),
    );
  }

  Widget? _ownerBar() {
    if (!_canEdit) return null;
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
                key: const Key('lf-edit'),
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                key: const Key('lf-close'),
                onPressed: _busy ? null : _close,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_closeLabel),
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
    final topPad = MediaQuery.paddingOf(context).top;

    return ListView(
      padding: EdgeInsets.only(
        top: topPad,
        bottom: AppTheme.spacingXl,
      ),
      children: [
        if (_post.imageIds.isNotEmpty)
          CampusGallery(
            imageIds: _post.imageIds,
            media: widget.services.media,
          ),
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
                children: [
                  StatusChip(
                    label: _post.type.label,
                    color: _post.type == LostFoundType.lost
                        ? scheme.error
                        : scheme.primary,
                  ),
                  if (!_post.isOpen) ...[
                    const SizedBox(width: AppTheme.spacingXs),
                    StatusChip(
                      label: _post.status.label,
                      color: scheme.outline,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                _post.title,
                key: const Key('lf-detail-title'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _infoRow(
                context,
                icon: Icons.place_outlined,
                label: '地点',
                value: _post.location,
              ),
              _infoRow(
                context,
                icon: Icons.event_outlined,
                label: _post.type == LostFoundType.lost ? '丢失时间' : '拾获时间',
                value: formatDateTime(_post.occurredAt),
              ),
              _infoRow(
                context,
                icon: Icons.schedule_outlined,
                label: '发布于',
                value: formatRelative(_post.createdAt),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                _post.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              _contactCard(context),
              const SizedBox(height: AppTheme.spacingMd),
              _authorRow(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppTheme.spacingXs),
          Text(
            '$label  ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
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
              Icon(Icons.chat_bubble_outline,
                  size: 18, color: scheme.primary),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '联系方式',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _post.contact,
                      key: const Key('lf-detail-contact'),
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

  Widget _authorRow(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final letter = _post.authorName.isEmpty
        ? '?'
        : String.fromCharCode(_post.authorName.runes.first);

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
        Text(_post.authorName, style: theme.textTheme.bodySmall),
        const SizedBox(width: AppTheme.spacingXs),
        Text(
          _post.authorClassName,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (_post.isMine) ...[
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
