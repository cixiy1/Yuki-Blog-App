import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';

/// 发布一条快递代取。
class ExpressEditorPage extends StatefulWidget {
  const ExpressEditorPage({super.key, required this.services});

  final CampusServices services;

  @override
  State<ExpressEditorPage> createState() => _ExpressEditorPageState();
}

class _ExpressEditorPageState extends State<ExpressEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _station = TextEditingController();
  final _code = TextEditingController();
  final _deliverTo = TextEditingController();
  final _reward = TextEditingController(text: '3');
  final _note = TextEditingController();

  late DateTime _deadline =
      DateTime.now().add(const Duration(hours: 4)).copyWith(second: 0, millisecond: 0, microsecond: 0);
  bool _schoolWide = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _station.dispose();
    _code.dispose();
    _deliverTo.dispose();
    _reward.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      helpText: '选择最晚送达日期',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
      helpText: '选择最晚送达时间',
    );
    if (time == null || !mounted) return;

    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_deadline.isAfter(DateTime.now())) {
      setState(() => _error = '最晚送达时间要晚于现在');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.services.express.create(
        station: _station.text.trim(),
        pickupCode: _code.text.trim(),
        deliverTo: _deliverTo.text.trim(),
        rewardCents: yuanToCents(_reward.text),
        deadline: _deadline,
        note: _note.text.trim(),
        schoolWide: _schoolWide,
      );
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
      setState(() => _error = '发布失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CampusSubPage(
      title: '发布代取',
      resizeToAvoidBottomInset: true,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            AppTheme.spacingMd,
            AppTheme.spacingXl,
          ),
          children: [
            TextFormField(
              key: const Key('ex-station'),
              controller: _station,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '取件地点',
                hintText: '如 菜鸟驿站（北门）',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写取件地点' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('ex-code'),
              controller: _code,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '取件码',
                hintText: '如 8-2-3021，只有接单人能看到',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写取件码' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('ex-deliver-to'),
              controller: _deliverTo,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '送达地点',
                hintText: '如 3栋412',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写送达地点' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('ex-reward'),
              controller: _reward,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '酬金',
                hintText: '0 表示免费帮忙',
                prefixText: '¥ ',
                helperText: '线下结算，系统不经手钱',
              ),
              validator: (v) {
                final raw = (v ?? '').trim();
                if (raw.isEmpty) return '请填写酬金';
                if (double.tryParse(raw) == null) return '酬金只能是数字';
                if (yuanToCents(raw) > 100000) return '酬金最多 1000 元';
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: _pickDeadline,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '最晚送达',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                child: Text(formatDateTime(_deadline)),
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            TextFormField(
              key: const Key('ex-note'),
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                hintText: '箱子重不重、要不要冷藏之类',
              ),
            ),
            SwitchListTile(
              key: const Key('ex-scope'),
              contentPadding: EdgeInsets.zero,
              value: _schoolWide,
              onChanged: (value) => setState(() => _schoolWide = value),
              title: const Text('全校可见'),
              subtitle: const Text('关闭时只有本班同学能接到这条委托'),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppTheme.spacingLg),
            ElevatedButton(
              key: const Key('ex-submit'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('发布'),
            ),
          ],
        ),
      ),
    );
  }
}
