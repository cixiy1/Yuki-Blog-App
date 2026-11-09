import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/permissions.dart';
import '../../../models/campus/campus_activity.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import 'activity_detail_page.dart';
import 'activity_editor_page.dart';
import 'widgets/activity_card.dart';

/// 活动列表：开放报名 / 我报名的 / 我发起的，管理员多一个待审核。
class ActivityListPage extends StatefulWidget {
  const ActivityListPage({super.key, required this.services});

  final CampusServices services;

  @override
  State<ActivityListPage> createState() => _ActivityListPageState();
}

class _ActivityListPageState extends State<ActivityListPage> {
  static const _open = 'open';
  static const _joined = 'joined';
  static const _mine = 'mine';
  static const _pending = 'pending';

  String _filter = _open;
  List<CampusActivity> _items = const [];
  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isAdmin =>
      can(widget.services.session.user?.role, Capability.reviewActivity);

  bool get _canCreate =>
      can(widget.services.session.user?.role, Capability.createActivity);

  List<({String value, String label})> get _filters => [
        (value: _open, label: '开放报名'),
        (value: _joined, label: '我报名的'),
        (value: _mine, label: '我发起的'),
        if (_isAdmin) (value: _pending, label: '待审核'),
      ];

  Future<void> _load() async {
    if (!_loadedOnce && mounted) setState(() => _loading = true);
    try {
      final page = await widget.services.activities.list(filter: _filter);
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

  Future<void> _select(String filter) async {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _items = const [];
    });
    await _load();
  }

  Future<void> _openDetail(CampusActivity activity) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(
          services: widget.services,
          activity: activity,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ActivityEditorPage(services: widget.services),
      ),
    );
    if (created == true && mounted) await _select(_mine);
  }

  @override
  Widget build(BuildContext context) {
    return CampusSubPage(
      title: '活动报名',
      padBodyTop: true,
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              key: const Key('ac-create'),
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('发起活动'),
            )
          : null,
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
          for (final item in _filters) ...[
            ChoiceChip(
              key: Key('ac-filter-${item.value}'),
              label: Text(item.label),
              selected: _filter == item.value,
              onSelected: (_) => _select(item.value),
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
            icon: switch (_filter) {
              _pending => Icons.fact_check_outlined,
              _mine => Icons.event_note_outlined,
              _joined => Icons.how_to_reg_outlined,
              _ => Icons.event_available_outlined,
            },
            title: switch (_filter) {
              _pending => '没有待审核的活动',
              _mine => '你还没发起过活动',
              _joined => '还没报名任何活动',
              _ => '暂时没有开放报名的活动',
            },
            message: switch (_filter) {
              _pending => '班委发起活动后会出现在这里',
              _mine => _canCreate ? '发一个试试，通过审核后同学就能报名' : '只有班委和管理员能发起活动',
              _joined => '在「开放报名」里挑一个报名，名额满了会自动进候补',
              _ => '过阵子再来看看',
            },
            actionLabel: _filter == _mine && _canCreate ? '发起活动' : null,
            onAction: _filter == _mine && _canCreate ? _create : null,
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
          final activity = _items[index];
          return ActivityCard(
            activity: activity,
            onTap: () => _openDetail(activity),
          );
        },
      ),
    );
  }
}
