import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/form_csv.dart';
import '../../../models/campus/campus_form.dart';
import '../shared/campus_sub_page.dart';
import '../shared/empty_state.dart';
import '../shared/file_exporter.dart';
import '../shared/section_header.dart';

/// 表单汇总：概览统计 + 明细表 + 导出 CSV。
class FormSummaryPage extends StatefulWidget {
  const FormSummaryPage({
    super.key,
    required this.services,
    required this.form,
    this.saveFile,
  });

  final CampusServices services;
  final CampusForm form;

  /// 落盘方式，默认写系统临时目录。测试注入假的，避免在 fake async 里做真 I/O。
  final TextFileSaver? saveFile;

  @override
  State<FormSummaryPage> createState() => _FormSummaryPageState();
}

class _FormSummaryPageState extends State<FormSummaryPage> {
  List<FormSubmission> _items = const [];
  bool _loading = true;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.services.forms.submissions(widget.form.id);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    if (_exporting || _items.isEmpty) return;
    setState(() => _exporting = true);

    String? path;
    Object? failure;
    try {
      final csv = buildFormCsv(widget.form, _items);
      path = await (widget.saveFile ?? saveTextFile)(
        fileName: formCsvFileName(widget.form),
        content: csv,
      );
    } catch (e) {
      failure = e;
    } finally {
      // 先把转圈关掉再弹窗：按钮上的进度圈会一直动，留着它页面永远不静止。
      if (mounted) setState(() => _exporting = false);
    }
    if (!mounted) return;

    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$failure')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('已导出'),
        content: Text(
          path == null
              ? 'CSV 已交给浏览器下载，去下载记录里找一下。'
              : 'CSV 存到了：\n$path',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: CampusSubPage(
        title: '汇总 · ${widget.form.title}',
        padBodyTop: true,
        actions: [
          IconButton(
            key: const Key('fm-export'),
            tooltip: '导出 CSV',
            onPressed: _items.isEmpty || _exporting ? null : _export,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: '看不到汇总',
            message: _error,
          ),
        ],
      );
    }

    return Column(
      children: [
        const TabBar(
          tabs: [
            Tab(text: '统计'),
            Tab(text: '明细'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _statsTab(),
              _detailsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statsTab() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_items.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            icon: Icons.inbox_outlined,
            title: '还没收到提交',
            message: '等同学填完，这里会实时出统计',
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingXl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          children: [
            Text(
              '已收 ${_items.length} / ${widget.form.targetCount}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${(_items.length / (widget.form.targetCount == 0 ? 1 : widget.form.targetCount) * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: widget.form.targetCount == 0
                ? 0
                : (_items.length / widget.form.targetCount).clamp(0, 1),
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: AppTheme.spacingLg),
        for (final field in widget.form.fields) _fieldStat(field),
      ],
    );
  }

  Widget _fieldStat(FormFieldSpec field) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: field.label),
          if (field.type.isChoice)
            for (final option in field.options)
              _optionBar(
                option.label,
                _items
                    .where((s) => _picked(field, s, option.id))
                    .length,
              )
          else if (field.type == FormFieldType.number)
            _numberSummary(field)
          else
            Text(
              '已填 ${_items.where((s) => !_blank(s.answers[field.id])).length} 份',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _optionBar(String label, int count) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = _items.isEmpty ? 1 : _items.length;
    final ratio = (count / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          SizedBox(
            width: 34,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numberSummary(FormFieldSpec field) {
    final theme = Theme.of(context);
    final values = [
      for (final s in _items)
        if (num.tryParse('${s.answers[field.id] ?? ''}') != null)
          num.parse('${s.answers[field.id]}'),
    ];
    if (values.isEmpty) {
      return Text(
        '还没有数字答案',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    final sum = values.fold<num>(0, (a, b) => a + b);
    final avg = sum / values.length;

    return Text(
      '${values.length} 份 · 平均 ${_trim(avg)} · 最小 ${_trim(values.reduce((a, b) => a < b ? a : b))}'
      ' · 最大 ${_trim(values.reduce((a, b) => a > b ? a : b))}'
      ' · 合计 ${_trim(sum)}',
      style: theme.textTheme.bodySmall,
    );
  }

  Widget _detailsTab() {
    if (_items.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            icon: Icons.table_chart_outlined,
            title: '还没有明细',
            message: '有人提交后这里会出现一张表',
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingMd,
        AppTheme.spacingXl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 48,
            columns: [
              const DataColumn(label: Text('提交人')),
              const DataColumn(label: Text('班级')),
              for (final field in widget.form.fields)
                DataColumn(label: Text(field.label)),
            ],
            rows: [
              for (final submission in _items)
                DataRow(
                  cells: [
                    DataCell(Text(submission.userName)),
                    DataCell(Text(submission.className)),
                    for (final field in widget.form.fields)
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            _answerText(field, submission.answers),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

bool _picked(FormFieldSpec field, FormSubmission submission, String optionId) {
  final value = submission.answers[field.id];
  if (value is List) return value.map((e) => '$e').contains(optionId);
  return '$value' == optionId;
}

bool _blank(Object? value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is List) return value.isEmpty;
  return false;
}

/// 选项 id → 选项文案；文本原样返回。
String _answerText(FormFieldSpec field, Map<String, dynamic> answers) {
  final value = answers[field.id];
  if (_blank(value)) return '—';

  String label(String id) {
    for (final option in field.options) {
      if (option.id == id) return option.label;
    }
    return id;
  }

  if (field.type == FormFieldType.multiChoice) {
    final ids = value is List ? value.map((e) => '$e') : <String>[];
    return ids.map(label).join('、');
  }
  if (field.type == FormFieldType.singleChoice) return label('$value');
  return '$value';
}

String _trim(num value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value';
