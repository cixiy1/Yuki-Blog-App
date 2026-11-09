import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/campus_activity.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';
import '../shared/image_picker_field.dart';

/// 发起 / 编辑活动。保存成功后 `pop(true)`。
class ActivityEditorPage extends StatefulWidget {
  const ActivityEditorPage({
    super.key,
    required this.services,
    this.existing,
    this.pickBytes,
  });

  final CampusServices services;
  final CampusActivity? existing;

  /// 测试注入口：默认走系统相册，用例里直接给字节。
  final ImageBytesPicker? pickBytes;

  @override
  State<ActivityEditorPage> createState() => _ActivityEditorPageState();
}

class _ActivityEditorPageState extends State<ActivityEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _capacity;

  late DateTime _startAt;
  late DateTime _deadline;
  DateTime? _endAt;
  late bool _schoolWide;
  late List<String> _imageIds;

  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final now = DateTime.now();
    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _capacity = TextEditingController(text: '${existing?.capacity ?? 20}');
    _startAt = existing?.startAt.toLocal() ??
        DateTime(now.year, now.month, now.day + 3, 19);
    _endAt = existing?.endAt?.toLocal();
    _deadline = existing?.signupDeadline.toLocal() ??
        _startAt.subtract(const Duration(days: 1));
    _schoolWide = existing?.scope.name == 'schoolWide';
    _imageIds = [...?existing?.imageIds];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  /// 日期 + 时间两步选。取消任意一步就当没改。
  Future<DateTime?> _pickDateTime(DateTime initial, {String? help}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: help,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: help,
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_deadline.isBefore(_startAt)) {
      setState(() => _error = '报名截止要早于活动开始');
      return;
    }
    if (_endAt != null && _endAt!.isBefore(_startAt)) {
      setState(() => _error = '结束时间不能早于开始时间');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = widget.services.activities;
    final capacity = int.tryParse(_capacity.text.trim()) ?? 0;
    try {
      if (_editing) {
        await repo.update(
          widget.existing!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          location: _location.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          signupDeadline: _deadline,
          capacity: capacity,
          imageIds: _imageIds,
          schoolWide: _schoolWide,
        );
      } else {
        await repo.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          location: _location.text.trim(),
          startAt: _startAt,
          endAt: _endAt,
          signupDeadline: _deadline,
          capacity: capacity,
          imageIds: _imageIds,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CampusSubPage(
      title: _editing ? '编辑活动' : '发起活动',
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
              key: const Key('ac-title'),
              controller: _title,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '活动名称',
                hintText: '如「周五篮球对抗赛」',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写活动名称' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('ac-location'),
              controller: _location,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '地点',
                hintText: '如「体育馆 2 号场」',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写地点' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('ac-capacity'),
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '名额',
                hintText: '满员后报名的人自动进候补',
              ),
              validator: (v) {
                final value = int.tryParse((v ?? '').trim());
                if (value == null) return '名额只能是整数';
                if (value < 1) return '名额至少 1 个';
                if (value > 500) return '名额最多 500 个';
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('ac-description'),
              controller: _description,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: '活动说明',
                hintText: '要带什么、怎么集合、有没有费用',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请写点活动说明' : null,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            _timeTile(
              key: 'ac-start',
              label: '活动开始',
              value: formatDateTime(_startAt),
              onTap: () async {
                final picked = await _pickDateTime(_startAt);
                if (picked != null && mounted) {
                  setState(() => _startAt = picked);
                }
              },
            ),
            _timeTile(
              key: 'ac-end',
              label: '活动结束',
              value: _endAt == null ? '可不填' : formatDateTime(_endAt!),
              onTap: () async {
                final picked = await _pickDateTime(
                  _endAt ?? _startAt.add(const Duration(hours: 2)),
                );
                if (picked != null && mounted) setState(() => _endAt = picked);
              },
              onClear: _endAt == null
                  ? null
                  : () => setState(() => _endAt = null),
            ),
            _timeTile(
              key: 'ac-deadline',
              label: '报名截止',
              value: formatDateTime(_deadline),
              onTap: () async {
                final picked = await _pickDateTime(_deadline);
                if (picked != null && mounted) {
                  setState(() => _deadline = picked);
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingSm),
            SwitchListTile(
              key: const Key('ac-scope'),
              contentPadding: EdgeInsets.zero,
              value: _schoolWide,
              onChanged: (value) => setState(() => _schoolWide = value),
              title: const Text('全校可见'),
              subtitle: const Text('关掉就只有本班同学能看到'),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            ImagePickerField(
              imageIds: _imageIds,
              media: widget.services.media,
              pickBytes: widget.pickBytes,
              onChanged: (ids) => setState(() => _imageIds = ids),
            ),
            if (!_editing) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                '提交后要等管理员审核通过，其他同学才看得到。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                _error!,
                key: const Key('ac-error'),
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppTheme.spacingLg),
            ElevatedButton(
              key: const Key('ac-submit'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editing ? '保存修改' : '提交审核'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeTile({
    required String key,
    required String label,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: InkWell(
        key: Key(key),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: onClear == null
                ? const Icon(Icons.edit_calendar_outlined, size: 18)
                : IconButton(
                    tooltip: '清空',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
          ),
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ),
    );
  }
}
