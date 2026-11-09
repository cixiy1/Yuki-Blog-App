import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/purchase_task.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import 'purchase_detail_page.dart';
import 'purchase_editor_page.dart';
import 'widgets/purchase_card.dart';

/// 列表里看哪一批任务。
enum PurchaseTab {
  pending('待接单'),
  active('进行中'),
  finished('已完成'),
  mine('我发布的'),
  courier('我接的');

  const PurchaseTab(this.label);

  final String label;

  String get status => switch (this) {
        PurchaseTab.pending => 'pending',
        PurchaseTab.active => 'active',
        PurchaseTab.finished => 'finished',
        PurchaseTab.mine || PurchaseTab.courier => 'all',
      };
}

/// 代买跑腿列表。
class PurchaseListPage extends StatefulWidget {
  const PurchaseListPage({super.key, required this.services});

  final CampusServices services;

  @override
  State<PurchaseListPage> createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends State<PurchaseListPage> {
  PurchaseTab _tab = PurchaseTab.pending;

  List<PurchaseTask> _items = const [];
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
      final page = await widget.services.purchases.list(
        status: _tab.status,
        onlyMine: _tab == PurchaseTab.mine,
        onlyCourier: _tab == PurchaseTab.courier,
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

  Future<void> _openDetail(PurchaseTask task) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PurchaseDetailPage(
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
        builder: (_) => PurchaseEditorPage(services: widget.services),
      ),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return CampusSubPage(
      title: '代买跑腿',
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
          for (final tab in PurchaseTab.values) ...[
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
            icon: Icons.delivery_dining_outlined,
            title: _emptyTitle,
            message: _emptyMessage,
            actionLabel: _tab == PurchaseTab.pending ? '发布一条' : null,
            onAction: _tab == PurchaseTab.pending ? _create : null,
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
          return PurchaseCard(
            task: task,
            onTap: () => _openDetail(task),
          );
        },
      ),
    );
  }

  String get _emptyTitle => switch (_tab) {
        PurchaseTab.pending => '暂时没有要代买的',
        PurchaseTab.active => '没有进行中的单',
        PurchaseTab.finished => '还没有完成的记录',
        PurchaseTab.mine => '你还没发过代买',
        PurchaseTab.courier => '你还没接过单',
      };

  String get _emptyMessage => switch (_tab) {
        PurchaseTab.pending => '顺路带杯奶茶，或者帮人跑个超市',
        PurchaseTab.active => '接了单的都会出现在这里',
        PurchaseTab.finished => '完成的单会留在这里，方便互评',
        PurchaseTab.mine => '写清买什么、送到哪、多少钱',
        PurchaseTab.courier => '去「待接单」看看有没有顺路的',
      };
}
