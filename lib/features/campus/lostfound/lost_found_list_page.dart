import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/lost_found_post.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import 'lost_found_detail_page.dart';
import 'lost_found_editor_page.dart';
import 'widgets/lost_found_card.dart';

/// 失物招领列表。
class LostFoundListPage extends StatefulWidget {
  const LostFoundListPage({super.key, required this.services});

  final CampusServices services;

  @override
  State<LostFoundListPage> createState() => _LostFoundListPageState();
}

class _LostFoundListPageState extends State<LostFoundListPage> {
  LostFoundType? _type;
  int? _days;

  List<LostFoundPost> _items = const [];
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
      final page = await widget.services.lostFound.list(
        type: _type,
        days: _days,
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

  Future<void> _openDetail(LostFoundPost post) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LostFoundDetailPage(
          services: widget.services,
          post: post,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LostFoundEditorPage(services: widget.services),
      ),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return CampusSubPage(
      title: '失物招领',
      actions: [
        PopupMenuButton<int?>(
          tooltip: '时间范围',
          icon: const Icon(Icons.filter_list_rounded),
          initialValue: _days,
          onSelected: (value) {
            setState(() => _days = value);
            _load();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: null, child: Text('不限时间')),
            PopupMenuItem(value: 7, child: Text('近 7 天')),
            PopupMenuItem(value: 30, child: Text('近 30 天')),
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
          _typeRow(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _typeRow() {
    final options = <(LostFoundType?, String)>[
      (null, '全部'),
      (LostFoundType.lost, '寻物'),
      (LostFoundType.found, '招领'),
    ];

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
          for (final (value, label) in options) ...[
            ChoiceChip(
              label: Text(label),
              selected: _type == value,
              onSelected: (_) {
                setState(() => _type = value);
                _load();
              },
            ),
            const SizedBox(width: AppTheme.spacingSm),
          ],
          if (_days != null)
            ActionChip(
              avatar: const Icon(Icons.schedule, size: 14),
              label: Text('近 $_days 天'),
              onPressed: () {
                setState(() => _days = null);
                _load();
              },
            ),
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
            icon: Icons.search_off_rounded,
            title: '这里还没有信息',
            message: '丢了东西或捡到东西，都可以发一条',
            actionLabel: '发布一条',
            onAction: _create,
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
          final post = _items[index];
          return LostFoundCard(
            post: post,
            media: widget.services.media,
            onTap: () => _openDetail(post),
          );
        },
      ),
    );
  }
}
