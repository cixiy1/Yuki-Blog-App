import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/permissions.dart';
import '../../../models/campus/campus_form.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import 'form_builder_page.dart';
import 'form_detail_page.dart';
import 'widgets/form_card.dart';

/// 表单列表：进行中 / 待我填 / 我建的。
class FormListPage extends StatefulWidget {
  const FormListPage({super.key, required this.services});

  final CampusServices services;

  @override
  State<FormListPage> createState() => _FormListPageState();
}

class _FormListPageState extends State<FormListPage> {
  static const _open = 'open';
  static const _todo = 'todo';
  static const _mine = 'mine';

  String _filter = _open;
  List<CampusForm> _items = const [];
  bool _loading = true;
  bool _loadedOnce = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _canCreate =>
      can(widget.services.session.user?.role, Capability.createForm);

  Future<void> _load() async {
    if (!_loadedOnce && mounted) setState(() => _loading = true);
    try {
      final page = await widget.services.forms.list(filter: _filter);
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

  Future<void> _openDetail(CampusForm form) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormDetailPage(services: widget.services, form: form),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormBuilderPage(services: widget.services),
      ),
    );
    if (created == true && mounted) await _select(_mine);
  }

  @override
  Widget build(BuildContext context) {
    return CampusSubPage(
      title: '表单收集',
      padBodyTop: true,
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              key: const Key('fm-create'),
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('建表'),
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
    const labels = {
      _open: '进行中',
      _todo: '待我填',
      _mine: '我建的',
    };

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
          for (final entry in labels.entries) ...[
            ChoiceChip(
              key: Key('fm-filter-${entry.key}'),
              label: Text(entry.value),
              selected: _filter == entry.key,
              onSelected: (_) => _select(entry.key),
            ),
            const SizedBox(width: AppTheme.spacingSm),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
              _todo => Icons.task_alt_rounded,
              _mine => Icons.assignment_outlined,
              _ => Icons.inbox_outlined,
            },
            title: switch (_filter) {
              _todo => '都填完了',
              _mine => '你还没建过表',
              _ => '暂时没有进行中的表',
            },
            message: switch (_filter) {
              _todo => '有新表要填时会出现在这里',
              _mine => _canCreate ? '建一张表，收齐信息后能导出 CSV' : '只有班委和管理员能建表',
              _ => '过阵子再来看看',
            },
            actionLabel: _filter == _mine && _canCreate ? '建一张表' : null,
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
          final form = _items[index];
          return FormCard(form: form, onTap: () => _openDetail(form));
        },
      ),
    );
  }
}
