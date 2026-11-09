import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/market_item.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import 'market_detail_page.dart';
import 'market_editor_page.dart';
import 'widgets/market_card.dart';

/// 二手闲置列表：分类筛选 + 排序 + 关键词搜索。
class MarketListPage extends StatefulWidget {
  const MarketListPage({super.key, required this.services});

  final CampusServices services;

  @override
  State<MarketListPage> createState() => _MarketListPageState();
}

class _MarketListPageState extends State<MarketListPage> {
  MarketCategory? _category;
  MarketSort _sort = MarketSort.latest;
  String _query = '';

  List<MarketItem> _items = const [];
  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loadedOnce && mounted) setState(() => _loading = true);
    try {
      final page = await widget.services.market.list(
        category: _category,
        sort: _sort,
        query: _query,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
        _loadedOnce = true;
        _error = null;
      });
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

  Future<void> _openDetail(MarketItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MarketDetailPage(
          services: widget.services,
          item: item,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MarketEditorPage(services: widget.services),
      ),
    );
    if (created == true && mounted) await _load();
  }

  Future<void> _search() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _MarketSearchDialog(initial: _query),
    );
    if (result == null || !mounted) return;
    setState(() => _query = result.trim());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return CampusSubPage(
      title: '二手闲置',
      actions: [
        IconButton(
          tooltip: '搜索',
          onPressed: _search,
          icon: const Icon(Icons.search_rounded),
        ),
        PopupMenuButton<MarketSort>(
          tooltip: '排序',
          icon: const Icon(Icons.swap_vert_rounded),
          initialValue: _sort,
          onSelected: (value) {
            setState(() => _sort = value);
            _load();
          },
          itemBuilder: (context) => [
            for (final sort in MarketSort.values)
              PopupMenuItem(value: sort, child: Text(sort.label)),
          ],
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('发布'),
      ),
      padBodyTop: true,
      body: Column(
        children: [
          _filterRow(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingSm,
        AppTheme.spacingMd,
        AppTheme.spacingXs,
      ),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('全部'),
            selected: _category == null,
            onSelected: (_) {
              setState(() => _category = null);
              _load();
            },
          ),
          for (final category in MarketCategory.values) ...[
            const SizedBox(width: AppTheme.spacingSm),
            ChoiceChip(
              label: Text(category.label),
              selected: _category == category,
              onSelected: (_) {
                setState(() => _category = category);
                _load();
              },
            ),
          ],
          if (_query.isNotEmpty) ...[
            const SizedBox(width: AppTheme.spacingSm),
            ActionChip(
              avatar: const Icon(Icons.search, size: 14),
              label: Text('“$_query”'),
              onPressed: () {
                setState(() => _query = '');
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: '加载失败',
            message: _error,
            actionLabel: '重试',
            onAction: _load,
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: _query.isEmpty ? '还没有在售的东西' : '没搜到相关物品',
            message: _query.isEmpty ? '闲置的书、数码、生活用品都能挂上来' : '换个关键词试试',
            actionLabel: _query.isEmpty ? '发布一件' : null,
            onAction: _query.isEmpty ? _create : null,
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingSm,
          AppTheme.spacingMd,
          96 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return MarketCard(
            item: item,
            media: widget.services.media,
            onTap: () => _openDetail(item),
          );
        },
      ),
    );
  }
}

/// 搜索弹窗自己持有 controller，关掉时随路由一起释放。
class _MarketSearchDialog extends StatefulWidget {
  const _MarketSearchDialog({required this.initial});

  final String initial;

  @override
  State<_MarketSearchDialog> createState() => _MarketSearchDialogState();
}

class _MarketSearchDialogState extends State<_MarketSearchDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('搜索闲置'),
      content: TextField(
        key: const Key('mk-search-input'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '物品名称或描述里的关键词',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          key: const Key('mk-search-submit'),
          onPressed: _submit,
          child: const Text('搜索'),
        ),
      ],
    );
  }
}
