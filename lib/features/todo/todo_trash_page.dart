import 'package:flutter/material.dart';

import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/features/todo/todo_model.dart';
import 'package:yuki_blog_app/widgets/immersive_scaffold.dart';

/// 回收站：列出已移入回收站的待办，可还原或彻底删除。
///
/// 数据仍由 [TodoPage] 持有，这里只负责展示与转发操作：
/// - [onRestore] 还原（改回正常列表，原分组 / 完成状态 / 截止日都保留）；
/// - [onDeleteForever] 彻底删除单条（远端项会记墓碑，不再被同步复活）；
/// - [onEmpty] 清空整个回收站。
///
/// 三个回调都会同步改调用方的数据，本页自己维护一份展示列表以免等重建。
class TodoTrashPage extends StatefulWidget {
  const TodoTrashPage({
    super.key,
    required this.items,
    required this.onRestore,
    required this.onDeleteForever,
    required this.onEmpty,
  });

  /// 回收站内容，调用方按删除时间倒序排好。
  final List<TodoItem> items;

  final ValueChanged<TodoItem> onRestore;
  final ValueChanged<TodoItem> onDeleteForever;
  final VoidCallback onEmpty;

  @override
  State<TodoTrashPage> createState() => _TodoTrashPageState();
}

class _TodoTrashPageState extends State<TodoTrashPage> {
  late List<TodoItem> _items = [...widget.items];

  void _restore(TodoItem item) {
    setState(() => _items = [for (final e in _items) if (e.id != item.id) e]);
    widget.onRestore(item);
  }

  void _deleteForever(TodoItem item) {
    setState(() => _items = [for (final e in _items) if (e.id != item.id) e]);
    widget.onDeleteForever(item);
  }

  Future<void> _emptyTrash() async {
    final ok = await _confirm(
      title: '清空回收站',
      content: '将彻底删除 ${_items.length} 条待办，删除后无法恢复。',
      confirmLabel: '清空',
    );
    if (!ok || !mounted) return;
    setState(() => _items = const []);
    widget.onEmpty();
  }

  Future<bool> _confirm({
    required String title,
    required String content,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ImmersiveScaffold(
      title: '回收站',
      actions: [
        if (_items.isNotEmpty)
          IconButton(
            tooltip: '清空回收站',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _emptyTrash,
          ),
        const SizedBox(width: 4),
      ],
      body: SafeArea(
        top: false,
        child: _items.isEmpty
            ? const _TrashEmpty()
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  12 + MediaQuery.paddingOf(context).top,
                  AppTheme.spacingMd,
                  AppTheme.spacingXl,
                ),
                children: [
                  const _TrashHint(),
                  const SizedBox(height: AppTheme.spacingMd),
                  for (final item in _items)
                    _TrashTile(
                      key: Key('trash-${item.id}'),
                      item: item,
                      onRestore: () => _restore(item),
                      onDeleteForever: () => _deleteForever(item),
                    ),
                ],
              ),
      ),
    );
  }
}

/// 顶部说明：回收站不与博客同步，彻底删除不可撤销。
class _TrashHint extends StatelessWidget {
  const _TrashHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMd,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '回收站只保存在本机，不会同步到博客；彻底删除后无法恢复。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 回收站里的一条：标题 + 来源 + 删除时间 + 还原 / 彻底删除。
class _TrashTile extends StatelessWidget {
  const _TrashTile({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final TodoItem item;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.source == TodoSource.remote)
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 4),
                  child: Icon(Icons.cloud_outlined,
                      size: 12, color: scheme.onSurfaceVariant),
                ),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
          if (item.note != null && item.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    formatTrashAge(item.deletedAt ?? item.createdAt),
                    item.groupLabel,
                    if (item.done) '已完成',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
              TextButton(
                onPressed: onRestore,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('还原', style: TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: onDeleteForever,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: scheme.error,
                ),
                child: const Text('彻底删除', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrashEmpty extends StatelessWidget {
  const _TrashEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline,
              size: 56,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            '回收站是空的',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '删除的待办会先放到这里',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
