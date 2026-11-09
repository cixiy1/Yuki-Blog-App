import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/permissions.dart';
import '../../../models/campus/campus_form.dart';
import '../shared/campus_sub_page.dart';
import '../shared/section_header.dart';
import '../shared/status_chip.dart';
import 'form_builder_page.dart';
import 'form_fill_page.dart';
import 'form_summary_page.dart';

/// 表单详情：看题目、去填写、看汇总、关闭。
class FormDetailPage extends StatefulWidget {
  const FormDetailPage({
    super.key,
    required this.services,
    required this.form,
  });

  final CampusServices services;
  final CampusForm form;

  @override
  State<FormDetailPage> createState() => _FormDetailPageState();
}

class _FormDetailPageState extends State<FormDetailPage> {
  late CampusForm _form = widget.form;
  bool _busy = false;
  bool _changed = false;

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  bool get _canSeeSummary =>
      _form.isMine ||
      can(widget.services.session.user?.role, Capability.viewFormSummary);

  Future<void> _reload() async {
    try {
      final fresh = await widget.services.forms.detail(_form.id);
      if (!mounted) return;
      setState(() {
        _form = fresh;
        _changed = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    }
  }

  Future<void> _fill() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormFillPage(services: widget.services, form: _form),
      ),
    );
    if (submitted == true && mounted) {
      await _reload();
      _toast('已提交');
    }
  }

  void _openSummary() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FormSummaryPage(services: widget.services, form: _form),
      ),
    );
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FormBuilderPage(services: widget.services, existing: _form),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _close() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关闭这张表？'),
        content: const Text('关闭后就没人能再提交，已收的答案仍然可以看和导出。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('不了'),
          ),
          TextButton(
            key: const Key('fm-close-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final closed = await widget.services.forms.close(_form.id);
      if (!mounted) return;
      setState(() {
        _form = closed;
        _changed = true;
      });
      _toast('已关闭');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remind() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final count = await widget.services.forms.remind(_form.id);
      if (!mounted) return;
      _toast(count == 0 ? '大家好像都填过了' : '已提醒 $count 人');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        title: '表单详情',
        actions: [
          if (_form.isMine) ...[
            IconButton(
              key: const Key('fm-edit'),
              tooltip: '编辑',
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: const Key('fm-remind'),
              tooltip: '催填',
              onPressed: _busy || !_form.isOpen ? null : _remind,
              icon: const Icon(Icons.notifications_active_outlined),
            ),
          ],
        ],
        bottomNavigationBar: _actionBar(),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        MediaQuery.paddingOf(context).top + AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingXl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _form.title,
                key: const Key('fm-detail-title'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            StatusChip(
              label: _form.status.label,
              color: _form.isOpen ? scheme.primary : scheme.outline,
            ),
          ],
        ),
        if (_form.description.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            _form.description,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
        const SizedBox(height: AppTheme.spacingMd),
        Row(
          children: [
            StatusChip(
              label: '已收 ${_form.submissionCount}/${_form.targetCount}',
              color: scheme.secondary,
              icon: Icons.inbox_outlined,
            ),
            const SizedBox(width: AppTheme.spacingXs),
            if (_form.deadline != null)
              StatusChip(label: '${_form.deadline} 截止', color: scheme.tertiary),
            if (_form.mySubmitted) ...[
              const SizedBox(width: AppTheme.spacingXs),
              StatusChip(
                label: '我已提交',
                color: scheme.primary,
                icon: Icons.check_rounded,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTheme.spacingLg),
        SectionHeader(title: '题目（${_form.fields.length}）'),
        for (var i = 0; i < _form.fields.length; i++) _fieldRow(i, _form.fields[i]),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          '由 ${_form.creatorName} 创建',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _fieldRow(int index, FormFieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1}. ${field.label}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (field.required) ...[
                const SizedBox(width: 2),
                Text(
                  '*',
                  style: TextStyle(color: scheme.error, fontSize: 13),
                ),
              ],
              const Spacer(),
              Text(
                field.type.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (field.type.isChoice)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 14),
              child: Text(
                field.options.map((o) => o.label).join(' / '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _actionBar() {
    final children = <Widget>[];

    if (_canSeeSummary && _form.submissionCount > 0) {
      children.add(
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('fm-summary'),
            onPressed: _openSummary,
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text('查看汇总'),
          ),
        ),
      );
    }

    if (_form.isOpen && !_form.isMine) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: AppTheme.spacingSm));
      }
      children.add(
        Expanded(
          child: ElevatedButton(
            key: const Key('fm-fill'),
            onPressed: _busy ? null : _fill,
            child: Text(_form.mySubmitted ? '修改我的提交' : '填写'),
          ),
        ),
      );
    } else if (_form.isOpen && _form.isMine) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: AppTheme.spacingSm));
      }
      children.add(
        Expanded(
          child: OutlinedButton(
            key: const Key('fm-close'),
            onPressed: _busy ? null : _close,
            child: const Text('关闭表单'),
          ),
        ),
      );
    }

    if (children.isEmpty) return null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingSm,
          AppTheme.spacingMd,
          AppTheme.spacingSm,
        ),
        child: Row(children: children),
      ),
    );
  }
}
