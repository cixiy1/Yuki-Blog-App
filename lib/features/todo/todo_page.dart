import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:yuki_blog_app/app/theme.dart';
import 'package:yuki_blog_app/core/todo_repository.dart';
import 'package:yuki_blog_app/features/todo/todo_model.dart';
import 'package:yuki_blog_app/features/todo/todo_storage.dart';

/// 全局自增 id 生成（避免同微秒内连续添加产生重复）。
int _idSeq = 0;
String _generateId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_idSeq++}';

/// 待办页：网络优先自动拉取博客《待办清单》文章，本地增删改查长期保留。
///
/// 被 [HomeShell] 的 [ImmersiveScaffold] 包裹，这里只返回 body。
/// - 打开即自动拉取远端（[TodoRemoteSource]），解析文章里的待办项并合并；
/// - 合并规则：远端决定「有哪些任务」及其标题/分类/截止；本机的完成状态、
///   自建任务、对远端任务的删除（墓碑）都持久化保留；
/// - 离线时回退到上一次合并后的本地数据，不丢本地改动。
class TodoPage extends StatefulWidget {
  const TodoPage({super.key, this.storage, this.remote});

  /// 注入自定义存储（测试用）；不传则使用 [FileTodoStorage]。
  final TodoStorage? storage;

  /// 注入自定义远端源（测试用）；不传则使用 [NetworkTodoRemoteSource]。
  final TodoRemoteSource? remote;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

enum _TodoFilter { all, active, done }

class _TodoPageState extends State<TodoPage> {
  late final TodoStorage _storage = widget.storage ??
      FileTodoStorage(getApplicationDocumentsDirectory());
  late final TodoRemoteSource _remote =
      widget.remote ?? NetworkTodoRemoteSource();

  List<TodoItem> _items = const [];
  Set<String> _deleted = const {};
  _TodoFilter _filter = _TodoFilter.all;
  bool _loading = true;
  bool _syncing = false;
  bool _offline = false;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await _storage.load();
    if (!mounted) return;
    setState(() {
      _items = store.items;
      _deleted = store.deletedRemoteIds;
      _loading = false;
    });
    // 打开即自动拉取远端并合并（自动拉取显示）。
    _sync();
  }

  /// 合并远端拉取结果与本地数据，规则见类注释。
  List<TodoItem> _merge(List<TodoItem> local, List<RemoteTodo> remote) {
    final remoteById = <String, RemoteTodo>{
      for (final r in remote) r.id: r
    };

    final result = <TodoItem>[];
    for (final item in local) {
      if (item.source == TodoSource.local) {
        // 本机自建：始终保留。
        result.add(item);
        continue;
      }
      final rid = item.remoteId;
      if (rid == null || _deleted.contains(rid)) {
        // 用户已删除该远端任务 → 墓碑，不再复活。
        continue;
      }
      final r = remoteById.remove(rid);
      if (r == null) {
        // 远端已移除该项 → 同步移除（不再「存在」）。
        continue;
      }
      // 远端仍在：刷新内容字段，保留本机完成状态。
      result.add(item.copyWith(
        title: r.title,
        note: r.note,
        category: r.category,
        dueLabel: r.dueLabel,
        dueDate: r.dueDate,
      ));
    }

    // 远端新增、本地未见过的项。
    for (final r in remoteById.values) {
      if (_deleted.contains(r.id)) continue;
      result.add(TodoItem(
        id: 'remote-${r.id}',
        remoteId: r.id,
        title: r.title,
        note: r.note,
        category: r.category,
        dueLabel: r.dueLabel,
        dueDate: r.dueDate,
        source: TodoSource.remote,
        done: false,
        createdAt: DateTime.now(),
      ));
    }
    return result;
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final remote = await _remote.fetch();
      if (!mounted) return;
      final merged = _merge(_items, remote);
      setState(() {
        _items = merged;
        _lastSync = DateTime.now();
        _offline = false;
      });
      await _persist();
    } on TodoNetworkException {
      if (!mounted) return;
      // 离线 / 代理异常：保留本地数据，仅标记离线。
      setState(() => _offline = true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _persist() async {
    await _storage.save(TodoStore(
      items: _items,
      deletedRemoteIds: _deleted,
    ));
  }

  void _addItem(TodoItem item) {
    setState(() => _items = [item, ..._items]);
    _persist();
  }

  void _updateItem(TodoItem item) {
    setState(() {
      _items = [for (final e in _items) e.id == item.id ? item : e];
    });
    _persist();
  }

  void _toggle(String id) {
    setState(() {
      _items = [
        for (final e in _items)
          e.id == id ? e.copyWith(done: !e.done) : e,
      ];
    });
    _persist();
  }

  void _remove(TodoItem item) {
    setState(() {
      if (item.remoteId != null) {
        // 远端任务：记入墓碑，下次拉取不再复活。
        _deleted = {..._deleted, item.remoteId!};
      }
      _items = [for (final e in _items) if (e.id != item.id) e];
    });
    _persist();
  }

  List<TodoItem> get _visible {
    final filtered = switch (_filter) {
      _TodoFilter.active => _items.where((e) => !e.done),
      _TodoFilter.done => _items.where((e) => e.done),
      _TodoFilter.all => _items.where((_) => true),
    };
    final list = [...filtered];
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      final ad = a.dueDate ?? _dateFromLabel(a.dueLabel);
      final bd = b.dueDate ?? _dateFromLabel(b.dueLabel);
      if (ad != null && bd != null) return ad.compareTo(bd);
      if (ad != null) return -1;
      if (bd != null) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  DateTime? _dateFromLabel(String? label) =>
      label == null ? null : _parseLabelDate(label);

  int get _activeCount => _items.where((e) => !e.done).length;

  Future<void> _showEditor({TodoItem? initial}) async {
    final result = await showDialog<TodoItem>(
      context: context,
      builder: (_) => _TodoEditorDialog(initial: initial),
    );
    if (result == null) return;
    if (initial == null) {
      _addItem(result);
    } else {
      _updateItem(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _sync,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                AppTheme.spacingSm + MediaQuery.paddingOf(context).top,
                AppTheme.spacingMd,
                AppTheme.spacingXl + 88,
              ),
              children: [
                _Header(
                  total: _items.length,
                  active: _activeCount,
                  filter: _filter,
                  onFilter: (f) => setState(() => _filter = f),
                  onRefresh: _sync,
                  syncing: _syncing,
                  offline: _offline,
                  lastSync: _lastSync,
                ),
                const SizedBox(height: AppTheme.spacingMd),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.spacingLg),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (visible.isEmpty)
                  _EmptyState(filter: _filter, offline: _offline)
                else
                  for (final item in visible)
                    _TodoTile(
                      key: Key(item.id),
                      item: item,
                      onToggle: () => _toggle(item.id),
                      onEdit: () => _showEditor(initial: item),
                      onDelete: () => _remove(item),
                    ),
              ],
            ),
          ),
          Positioned(
            right: AppTheme.spacingLg,
            bottom: AppTheme.spacingLg,
            child: FloatingActionButton(
              tooltip: '新建待办',
              onPressed: () => _showEditor(),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部：统计 + 筛选 + 同步状态与手动刷新。
class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.active,
    required this.filter,
    required this.onFilter,
    required this.onRefresh,
    required this.syncing,
    required this.offline,
    required this.lastSync,
  });

  final int total;
  final int active;
  final _TodoFilter filter;
  final ValueChanged<_TodoFilter> onFilter;
  final VoidCallback onRefresh;
  final bool syncing;
  final bool offline;
  final DateTime? lastSync;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final syncing = this.syncing;
    final lastSync = this.lastSync;
    final offline = this.offline;

    final syncHint = syncing
        ? '同步中…'
        : offline
            ? '离线，显示本地'
            : lastSync == null
                ? '未同步'
                : '已同步';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(Icons.checklist,
                  size: 20, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text(
                total == 0 ? '暂无待办' : '$active 项待完成 · 共 $total 项',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: syncing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Icon(Icons.refresh,
                      color: scheme.onSurfaceVariant, size: 20),
              onPressed: syncing ? null : onRefresh,
              tooltip: '同步待办',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            syncHint,
            style: TextStyle(
              fontSize: 11.5,
              color: offline
                  ? scheme.onSurfaceVariant
                  : scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        SegmentedButton<_TodoFilter>(
          showSelectedIcon: false,
          selected: {filter},
          onSelectionChanged: (set) => onFilter(set.first),
          segments: const [
            ButtonSegment(value: _TodoFilter.all, label: Text('全部')),
            ButtonSegment(value: _TodoFilter.active, label: Text('进行中')),
            ButtonSegment(value: _TodoFilter.done, label: Text('已完成')),
          ],
        ),
      ],
    );
  }
}

/// 空状态提示，文案随筛选与离线状态变化。
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter, this.offline = false});

  final _TodoFilter filter;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = switch (filter) {
      _TodoFilter.active => '没有进行中的待办，去放松一下吧',
      _TodoFilter.done => '还没有已完成的任务',
      _TodoFilter.all =>
        offline ? '暂未联网，本地也没有待办' : '点右下角 + 添加你的第一条待办',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_rtl_outlined,
                size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              hint,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条待办：勾选 / 分类 / 截止日 / 编辑 / 滑动删除。
class _TodoTile extends StatelessWidget {
  const _TodoTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _categoryColor(item.category, scheme);

    final dueText = item.dueText(done: item.done);
    final dueOverdue = dueText != null &&
        !item.done &&
        (dueText.startsWith('逾期') || dueText.contains('逾期'));

    return Dismissible(
      key: Key('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacingLg),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Checkbox(
                    value: item.done,
                    onChanged: (_) => onToggle(),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingXs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (item.source == TodoSource.remote)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.cloud_outlined,
                                  size: 12, color: scheme.onSurfaceVariant),
                            ),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: item.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.done
                                    ? scheme.onSurface.withValues(alpha: 0.45)
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.note != null && item.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.note!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: item.done
                                ? scheme.onSurfaceVariant
                                    .withValues(alpha: 0.6)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AppTheme.spacingXs,
                        runSpacing: AppTheme.spacingXs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                accent.withValues(alpha: 0.14),
                            label: Text(
                              item.category.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                            avatar: Icon(item.category.icon,
                                size: 13, color: accent),
                            padding: EdgeInsets.zero,
                          ),
                          if (dueText != null)
                            Text(
                              dueText,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: dueOverdue
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  onPressed: onDelete,
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(TodoCategory c, ColorScheme s) {
    switch (c) {
      case TodoCategory.classAffairs:
        return s.primary;
      case TodoCategory.party:
        return s.tertiary;
      case TodoCategory.personal:
        return s.secondary;
      case TodoCategory.other:
        return s.outline;
    }
  }
}

/// 新建 / 编辑对话框。
class _TodoEditorDialog extends StatefulWidget {
  const _TodoEditorDialog({this.initial});

  final TodoItem? initial;

  @override
  State<_TodoEditorDialog> createState() => _TodoEditorDialogState();
}

class _TodoEditorDialogState extends State<_TodoEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  late TodoCategory _category;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleCtl.text = widget.initial?.title ?? '';
    _noteCtl.text = widget.initial?.note ?? '';
    _category = widget.initial?.category ?? TodoCategory.other;
    _dueDate = widget.initial?.dueDate;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final initial = widget.initial;
    final item = TodoItem(
      id: initial?.id ?? _generateId(),
      title: _titleCtl.text.trim(),
      note: _noteCtl.text.trim().isEmpty ? null : _noteCtl.text.trim(),
      category: _category,
      done: initial?.done ?? false,
      createdAt: initial?.createdAt,
      dueDate: _dueDate,
      // 远端项被编辑时转为本地自建，避免下次拉取被远端覆盖。
      source: initial?.source == TodoSource.remote
          ? TodoSource.local
          : (initial?.source ?? TodoSource.local),
      remoteId: initial?.source == TodoSource.remote
          ? null
          : initial?.remoteId,
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = widget.initial != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑待办' : '新建待办'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleCtl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '标题'),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : '请填写标题',
              ),
              const SizedBox(height: AppTheme.spacingSm),
              TextFormField(
                controller: _noteCtl,
                decoration: const InputDecoration(labelText: '备注（可选）'),
                maxLines: 2,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text('分类',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: AppTheme.spacingXs),
              Wrap(
                spacing: AppTheme.spacingXs,
                children: [
                  for (final c in TodoCategory.valuesOrdered)
                    ChoiceChip(
                      selected: _category == c,
                      label: Text(c.label),
                      avatar: Icon(c.icon, size: 16),
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppTheme.spacingXs),
                  TextButton(
                    onPressed: _pickDue,
                    child: Text(_dueDate == null
                        ? '添加截止日期'
                        : '${_dueDate!.month}月${_dueDate!.day}日'),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _dueDate = null),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? '保存' : '添加'),
        ),
      ],
    );
  }
}

/// 与远端解析共用：从截止文案抽日期（见 [parseTodoHtml] 内的同名实现）。
DateTime? _parseLabelDate(String label) {
  final m = RegExp(r'(\d{1,2})[.月/](\d{1,2})').firstMatch(label);
  if (m == null) return null;
  final month = int.tryParse(m.group(1)!);
  final day = int.tryParse(m.group(2)!);
  if (month == null || day == null || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final now = DateTime.now();
  try {
    return DateTime(now.year, month, day);
  } on ArgumentError {
    return null;
  }
}
