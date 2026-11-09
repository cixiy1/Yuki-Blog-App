import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/express_task.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import 'express_detail_page.dart';
import 'express_editor_page.dart';
import 'widgets/express_card.dart';

/// 列表里看哪一批任务。
enum ExpressTab {
  pending('待接单'),
  active('进行中'),
  finished('已完成'),
  mine('我发布的'),
  courier('我接的');

  const ExpressTab(this.label);

  final String label;

  String get status => switch (this) {
        ExpressTab.pending => 'pending',
        ExpressTab.active => 'active',
        ExpressTab.finished => 'finished',
        ExpressTab.mine || ExpressTab.courier => 'all',
      };
}

/// 快递代取列表。
class ExpressListPage extends StatefulWidget {
  const ExpressListPage({super.key, required this.services});

  final CampusServices services;

  @override
  State<ExpressListPage> createState() => _ExpressListPageState();
}

class _ExpressListPageState extends State<ExpressListPage> {
  ExpressTab _tab = ExpressTab.pending;

  List<ExpressTask> _items = const [];
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
      final page = await widget.services.express.list(
        status: _tab.status,
        onlyMine: _tab == ExpressTab.mine,
        onlyCourier: _tab == ExpressTab.courier,
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

  Future<void> _openDetail(ExpressTask task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpressDetailPage(
          services: widget.services,
          task: task,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpressEditorPage(services: widget.services),
      ),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return CampusSubPage(
      title: '快递代取',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('发布'),
      ),
      padBodyTop: true,
      body: Column(
        children: [
          _tabRow(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _tabRow() {
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
          for (final tab in ExpressTab.values) ...[
            ChoiceChip(
              label: Text(tab.label),
              selected: _tab == tab,
              onSelected: (_) {
                setState(() => _tab = tab);
                _load();
              },
            ),
            const SizedBox(width: AppTheme.spacingSm),
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
            icon: Icons.inbox_outlined,
            title: _emptyTitle,
            message: _emptyMessage,
            actionLabel: _tab == ExpressTab.pending ? '发布一条' : null,
            onAction: _tab == ExpressTab.pending ? _create : null,
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
          final task = _items[index];
          return ExpressCard(
            task: task,
            onTap: () => _openDetail(task),
          );
        },
      ),
    );
  }

  String get _emptyTitle => switch (_tab) {
        ExpressTab.pending => '暂时没人要求代取',
        ExpressTab.active => '没有进行中的单',
        ExpressTab.finished => '还没有完成的记录',
        ExpressTab.mine => '你还没发过代取',
        ExpressTab.courier => '你还没接过单',
      };

  String get _emptyMessage => switch (_tab) {
        ExpressTab.pending => '帮人带个快递，顺手赚杯奶茶钱',
        ExpressTab.active => '接了单的都会出现在这里',
        ExpressTab.finished => '确认完成的单会留在这里备查',
        ExpressTab.mine => '把取件码和送达地点写清楚，别人接得更快',
        ExpressTab.courier => '去「待接单」看看有没有顺路的',
      };
}
