import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/lost_found_post.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';
import '../shared/image_picker_field.dart';

/// 发布 / 编辑失物招领。保存成功后 `pop(true)`，由列表页刷新。
class LostFoundEditorPage extends StatefulWidget {
  const LostFoundEditorPage({
    super.key,
    required this.services,
    this.existing,
    this.pickBytes,
  });

  final CampusServices services;
  final LostFoundPost? existing;

  /// 测试注入口：默认走系统相册，用例里直接给字节。
  final ImageBytesPicker? pickBytes;

  @override
  State<LostFoundEditorPage> createState() => _LostFoundEditorPageState();
}

class _LostFoundEditorPageState extends State<LostFoundEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _contact;

  late LostFoundType _type;
  late DateTime _occurredAt;
  late List<String> _imageIds;

  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _location = TextEditingController(text: existing?.location ?? '');
    _contact = TextEditingController(text: existing?.contact ?? '');
    _type = existing?.type ?? LostFoundType.lost;
    _occurredAt = existing?.occurredAt ?? DateTime.now();
    _imageIds = [...?existing?.imageIds];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
      helpText: '选择丢失 / 拾获日期',
    );
    if (picked == null) return;
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = widget.services.lostFound;
    try {
      if (_editing) {
        await repo.update(
          widget.existing!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          location: _location.text.trim(),
          contact: _contact.text.trim(),
          occurredAt: _occurredAt,
          imageIds: _imageIds,
        );
      } else {
        await repo.create(
          type: _type,
          title: _title.text.trim(),
          description: _description.text.trim(),
          location: _location.text.trim(),
          contact: _contact.text.trim(),
          occurredAt: _occurredAt,
          imageIds: _imageIds,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.fieldErrors.isNotEmpty
            ? e.fieldErrors.values.first
            : e.message;
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
      title: _editing ? '编辑信息' : '发布信息',
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
            SegmentedButton<LostFoundType>(
              segments: const [
                ButtonSegment(value: LostFoundType.lost, label: Text('我丢了')),
                ButtonSegment(value: LostFoundType.found, label: Text('我捡到')),
              ],
              selected: {_type},
              onSelectionChanged: _editing
                  ? null
                  : (values) => setState(() => _type = values.first),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            TextFormField(
              key: const Key('lf-title'),
              controller: _title,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '一句话说清是什么',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? '请填写标题' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('lf-description'),
              controller: _description,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '详细描述',
                hintText: '外观特征、里面有什么、什么时候发现的',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? '请填写描述' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('lf-location'),
              controller: _location,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '地点',
                hintText: '如 三饭二楼 / 图书馆三楼',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? '请填写地点' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('lf-contact'),
              controller: _contact,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: '联系方式',
                hintText: '手机号或微信号，方便失主联系',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? '请留个联系方式' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '丢失 / 拾获日期',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(formatDate(_occurredAt)),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            ImagePickerField(
              imageIds: _imageIds,
              media: widget.services.media,
              pickBytes: widget.pickBytes,
              onChanged: (ids) => setState(() => _imageIds = ids),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppTheme.spacingLg),
            ElevatedButton(
              key: const Key('lf-submit'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editing ? '保存修改' : '发布'),
            ),
          ],
        ),
      ),
    );
  }
}
