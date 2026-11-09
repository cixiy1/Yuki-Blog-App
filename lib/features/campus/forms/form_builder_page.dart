import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/campus_form.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';
import '../shared/section_header.dart';

/// 建表 / 改表。
///
/// 题目是一份可增删的草稿列表，保存时一次性提交整份结构。
/// 已经有人提交过的表不能再改题目（服务端也会拒），这里直接把编辑器锁掉。
class FormBuilderPage extends StatefulWidget {
  const FormBuilderPage({super.key, required this.services, this.existing});

  final CampusServices services;
  final CampusForm? existing;

  @override
  State<FormBuilderPage> createState() => _FormBuilderPageState();
}

class _FormBuilderPageState extends State<FormBuilderPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _fields = <_FieldDraft>[];

  String? _deadline;
  bool _schoolWide = false;
  bool _saving = false;
  String? _error;
  int _seq = 0;

  bool get _editing => widget.existing != null;

  /// 有人填过就不能动结构了。
  bool get _locked =>
      _editing && (widget.existing?.submissionCount ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title.text = existing?.title ?? '';
    _description.text = existing?.description ?? '';
    _deadline = existing?.deadline;
    _schoolWide = existing?.scope.name == 'schoolWide';

    for (final spec in existing?.fields ?? const <FormFieldSpec>[]) {
      _fields.add(_FieldDraft.fromSpec(spec));
      _seq++;
    }
    if (!_editing) _addField();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _addField() {
    setState(() {
      _fields.add(_FieldDraft.create(seq: ++_seq));
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index).dispose();
    });
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_deadline ?? '') ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() => _deadline = formatDate(picked));
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请填写表单名称');
      return;
    }

    final specs = <FormFieldSpec>[];
    if (!_locked) {
      final problem = _collectFields(specs);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = widget.services.forms;
    try {
      if (_editing) {
        await repo.update(
          widget.existing!.id,
          title: title,
          description: _description.text.trim(),
          deadline: _deadline,
          fields: _locked ? null : specs,
          schoolWide: _schoolWide,
        );
      } else {
        await repo.create(
          title: title,
          description: _description.text.trim(),
          fields: specs,
          deadline: _deadline,
          schoolWide: _schoolWide,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.fieldErrors.isNotEmpty ? e.fieldErrors.values.first : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 把草稿转成字段定义；有问题返回第一句人话。
  String? _collectFields(List<FormFieldSpec> out) {
    if (_fields.isEmpty) return '至少加一个题目';

    for (var i = 0; i < _fields.length; i++) {
      final draft = _fields[i];
      final label = draft.label.text.trim();
      if (label.isEmpty) return '第 ${i + 1} 个题目还没写标题';

      final options = <FormOption>[];
      if (draft.type.isChoice) {
        for (final option in draft.options) {
          final text = option.controller.text.trim();
          if (text.isEmpty) continue;
          options.add(FormOption(id: option.id, label: text));
        }
        if (options.length < 2) return '「$label」至少要两个选项';
      }

      out.add(
        FormFieldSpec(
          id: draft.id,
          type: draft.type,
          label: label,
          required: draft.required,
          options: options,
          hint: null,
          maxLength: draft.type == FormFieldType.multiLine
              ? 200
              : (draft.type.isText ? 100 : null),
          min: draft.type == FormFieldType.number ? 0 : null,
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CampusSubPage(
      title: _editing ? '编辑表单' : '建一张表',
      resizeToAvoidBottomInset: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingMd,
          AppTheme.spacingMd,
          AppTheme.spacingXl,
        ),
        children: [
          TextField(
            key: const Key('fm-title'),
            controller: _title,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '表单名称',
              hintText: '如「教材选购登记」',
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          TextField(
            key: const Key('fm-description'),
            controller: _description,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: '说明',
              hintText: '为什么收、什么时候截止、怎么用这些信息',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          InkWell(
            key: const Key('fm-deadline'),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: _pickDeadline,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '截止日期',
                suffixIcon: Icon(Icons.edit_calendar_outlined, size: 18),
              ),
              child: Text(
                _deadline ?? '不设截止',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          SwitchListTile(
            key: const Key('fm-scope'),
            contentPadding: EdgeInsets.zero,
            value: _schoolWide,
            onChanged: (value) => setState(() => _schoolWide = value),
            title: const Text('全校可见'),
            subtitle: const Text('关掉就只有本班同学能填'),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          SectionHeader(
            title: '题目',
            actionLabel: _locked ? null : '加一题',
            onAction: _locked ? null : _addField,
          ),
          if (_locked)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              child: Text(
                '已经有人提交了，题目不能再改——改了老答案就对不上了。',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          for (var i = 0; i < _fields.length; i++)
            _locked
                ? _lockedTile(i, _fields[i])
                : _fieldEditor(i, _fields[i]),
          if (_error != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              _error!,
              key: const Key('fm-builder-error'),
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          ElevatedButton(
            key: const Key('fm-builder-submit'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_editing ? '保存修改' : '建表'),
          ),
        ],
      ),
    );
  }

  Widget _lockedTile(int index, _FieldDraft draft) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Row(
        children: [
          Text('${index + 1}. ',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Expanded(
            child: Text(
              draft.label.text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            draft.type.label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _fieldEditor(int index, _FieldDraft draft) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      key: Key('fm-field-$index'),
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '第 ${index + 1} 题',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              IconButton(
                tooltip: '删除这题',
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeField(index),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          TextField(
            key: Key('fm-label-$index'),
            controller: draft.label,
            decoration: const InputDecoration(
              labelText: '题目',
              isDense: true,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<FormFieldType>(
                  key: Key('fm-type-$index'),
                  initialValue: draft.type,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: '类型',
                    isDense: true,
                  ),
                  items: [
                    for (final type in FormFieldType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => draft.setType(value));
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                // 卡片自己有底色，SwitchListTile 得挂在透明 Material 上，
                // 否则墨水效果会被这层 DecoratedBox 盖住（框架会断言）。
                child: Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: draft.required,
                    onChanged: (value) => setState(() => draft.required = value),
                    title: const Text('必填', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          if (draft.type.isChoice) ...[
            const SizedBox(height: AppTheme.spacingSm),
            for (var o = 0; o < draft.options.length; o++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('fm-option-$index-$o'),
                        controller: draft.options[o].controller,
                        decoration: const InputDecoration(
                          hintText: '选项文案',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '删掉这个选项',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                        () => draft.removeOption(draft.options[o]),
                      ),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              key: Key('fm-add-option-$index'),
              onPressed: () => setState(draft.addOption),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('加选项'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 一个题目草稿。文案用 controller 存，直接跟着输入框走。
class _FieldDraft {
  _FieldDraft({
    required this.id,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
  });

  factory _FieldDraft.create({required int seq}) => _FieldDraft(
        id: 'f_${DateTime.now().millisecondsSinceEpoch}_$seq',
        label: TextEditingController(),
        type: FormFieldType.singleLine,
        required: false,
        options: [],
      );

  factory _FieldDraft.fromSpec(FormFieldSpec spec) => _FieldDraft(
        id: spec.id,
        label: TextEditingController(text: spec.label),
        type: spec.type,
        required: spec.required,
        options: [
          for (final option in spec.options) _OptionDraft(option.id, option.label),
        ],
      );

  final String id;
  final TextEditingController label;
  FormFieldType type;
  bool required;
  final List<_OptionDraft> options;

  /// 切成选择类时先塞两个空选项，省得用户对着空列表发愣。
  void setType(FormFieldType next) {
    type = next;
    if (next.isChoice && options.isEmpty) {
      addOption();
      addOption();
    }
  }

  void addOption() {
    options.add(
      _OptionDraft('${id}_o${options.length + 1}', ''),
    );
  }

  void removeOption(_OptionDraft option) {
    options.remove(option);
    option.dispose();
  }

  void dispose() {
    label.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _OptionDraft {
  _OptionDraft(this.id, String text)
      : controller = TextEditingController(text: text);

  final String id;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}
