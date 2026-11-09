import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/form_answer_validator.dart';
import '../../../models/campus/campus_form.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';

/// 按题目定义渲染填报页。字段类型决定控件，校验规则来自
/// [validateAnswers]——和服务端是同一份。
class FormFillPage extends StatefulWidget {
  const FormFillPage({
    super.key,
    required this.services,
    required this.form,
  });

  final CampusServices services;
  final CampusForm form;

  @override
  State<FormFillPage> createState() => _FormFillPageState();
}

class _FormFillPageState extends State<FormFillPage> {
  final _controllers = <String, TextEditingController>{};
  final _answers = <String, dynamic>{};
  Map<String, String> _errors = const {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.form.fields) {
      final value = widget.form.myAnswers[field.id];
      if (field.type.isChoice) {
        _answers[field.id] = field.type == FormFieldType.multiChoice
            ? [..._asList(value)]
            : (value is String ? value : null);
      } else {
        final text = value == null ? '' : '$value';
        _answers[field.id] = text;
        _controllers[field.id] = TextEditingController(text: text);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final errors = validateAnswers(widget.form.fields, _answers);
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _error = '还有 ${errors.length} 处需要改一下';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errors = const {};
      _error = null;
    });

    try {
      await widget.services.forms.submit(widget.form.id, _answers);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = e.fieldErrors;
        _error = e.fieldErrors.isNotEmpty
            ? '还有 ${e.fieldErrors.length} 处需要改一下'
            : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '提交失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CampusSubPage(
      title: widget.form.mySubmitted ? '修改提交' : '填写表单',
      resizeToAvoidBottomInset: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd,
          AppTheme.spacingMd,
          AppTheme.spacingMd,
          AppTheme.spacingXl,
        ),
        children: [
          Text(
            widget.form.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (widget.form.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.form.description,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          for (final field in widget.form.fields) _buildField(field),
          if (_error != null) ...[
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              _error!,
              key: const Key('ff-error'),
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          ElevatedButton(
            key: const Key('ff-submit'),
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.form.mySubmitted ? '保存修改' : '提交'),
          ),
        ],
      ),
    );
  }

  Widget _buildField(FormFieldSpec field) {
    final theme = Theme.of(context);
    final error = _errors[field.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (field.required) ...[
                Text(
                  '* ',
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                ),
              ],
              Expanded(
                child: Text(
                  field.label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                field.type.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          switch (field.type) {
            FormFieldType.multiLine => _textField(field, maxLines: 4),
            FormFieldType.singleLine ||
            FormFieldType.studentId ||
            FormFieldType.number =>
              _textField(field),
            FormFieldType.date => _dateField(field),
            FormFieldType.singleChoice => _singleChoice(field),
            FormFieldType.multiChoice => _multiChoice(field),
          },
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error,
              key: Key('ff-error-${field.id}'),
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _textField(FormFieldSpec field, {int maxLines = 1}) {
    final isNumber = field.type == FormFieldType.number;
    final isStudentId = field.type == FormFieldType.studentId;

    return TextField(
      key: Key('ff-${field.id}'),
      controller: _controllers[field.id],
      maxLines: maxLines,
      keyboardType: isNumber || isStudentId
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: [
        if (isStudentId) FilteringTextInputFormatter.digitsOnly,
        if (field.maxLength != null) LengthLimitingTextInputFormatter(
          field.maxLength!,
        ),
      ],
      decoration: InputDecoration(
        hintText: field.hint ??
            (isNumber && (field.min != null || field.max != null)
                ? '范围 ${field.min ?? '-'} ~ ${field.max ?? '-'}'
                : null),
        errorText: _errors[field.id] == null ? null : ' ',
      ),
      onChanged: (value) {
        _answers[field.id] = value;
        if (_errors.containsKey(field.id)) {
          setState(() => _errors = {..._errors}..remove(field.id));
        }
      },
    );
  }

  Widget _dateField(FormFieldSpec field) {
    final value = _answers[field.id];
    final text = value is String && value.isNotEmpty ? value : '选择日期';

    return InkWell(
      key: Key('ff-${field.id}'),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: () async {
        final now = DateTime.now();
        final initial = DateTime.tryParse('$value') ?? now;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
        );
        if (picked == null || !mounted) return;
        setState(() {
          _answers[field.id] = formatDate(picked);
          _errors = {..._errors}..remove(field.id);
        });
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.edit_calendar_outlined, size: 18),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: value is String && value.isNotEmpty
                    ? null
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  Widget _singleChoice(FormFieldSpec field) {
    final selected = _answers[field.id];

    return Wrap(
      spacing: AppTheme.spacingXs,
      runSpacing: 4,
      children: [
        for (final option in field.options)
          ChoiceChip(
            key: Key('ff-${field.id}-${option.id}'),
            label: Text(option.label),
            selected: selected == option.id,
            onSelected: (_) => setState(() {
              _answers[field.id] = option.id;
              _errors = {..._errors}..remove(field.id);
            }),
          ),
      ],
    );
  }

  Widget _multiChoice(FormFieldSpec field) {
    final selected = _asList(_answers[field.id]);

    return Wrap(
      spacing: AppTheme.spacingXs,
      runSpacing: 4,
      children: [
        for (final option in field.options)
          FilterChip(
            key: Key('ff-${field.id}-${option.id}'),
            label: Text(option.label),
            selected: selected.contains(option.id),
            onSelected: (on) => setState(() {
              final next = [...selected];
              if (on) {
                next.add(option.id);
              } else {
                next.remove(option.id);
              }
              _answers[field.id] = next;
              _errors = {..._errors}..remove(field.id);
            }),
          ),
      ],
    );
  }
}

/// 宽松地把任意值读成字符串列表，用于回填多选。
List<String> _asList(Object? value) {
  if (value is List) {
    return [
      for (final item in value)
        if (item != null && '$item'.isNotEmpty) '$item',
    ];
  }
  if (value is String && value.isNotEmpty) return [value];
  return const [];
}
