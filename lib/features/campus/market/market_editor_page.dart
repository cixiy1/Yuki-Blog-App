import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../models/campus/market_item.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';
import '../shared/image_picker_field.dart';

/// 发布 / 编辑二手物品。保存成功后 `pop(true)`。
class MarketEditorPage extends StatefulWidget {
  const MarketEditorPage({
    super.key,
    required this.services,
    this.existing,
    this.pickBytes,
  });

  final CampusServices services;
  final MarketItem? existing;

  /// 测试注入口：默认走系统相册，用例里直接给字节。
  final ImageBytesPicker? pickBytes;

  @override
  State<MarketEditorPage> createState() => _MarketEditorPageState();
}

class _MarketEditorPageState extends State<MarketEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _contact;
  late final TextEditingController _price;

  late MarketCategory _category;
  late ItemCondition _condition;
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
    _contact = TextEditingController(text: existing?.contact ?? '');
    _price = TextEditingController(
      text: existing == null ? '' : centsToYuan(existing.priceCents),
    );
    _category = existing?.category ?? MarketCategory.book;
    _condition = existing?.condition ?? ItemCondition.likeNew;
    _imageIds = [...?existing?.imageIds];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _contact.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final priceCents = yuanToCents(_price.text);
    setState(() {
      _saving = true;
      _error = null;
    });

    final repo = widget.services.market;
    try {
      if (_editing) {
        await repo.update(
          widget.existing!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          contact: _contact.text.trim(),
          priceCents: priceCents,
          condition: _condition,
          category: _category,
          imageIds: _imageIds,
        );
      } else {
        await repo.create(
          title: _title.text.trim(),
          description: _description.text.trim(),
          contact: _contact.text.trim(),
          priceCents: priceCents,
          condition: _condition,
          category: _category,
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
      title: _editing ? '编辑物品' : '发布闲置',
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
              key: const Key('mk-title'),
              controller: _title,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '物品名称，如「宿舍小台灯」',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写标题' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('mk-price'),
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '价格',
                hintText: '0 表示赠送',
                prefixText: '¥ ',
              ),
              validator: (v) {
                final raw = (v ?? '').trim();
                if (raw.isEmpty) return '请填写价格';
                final cents = yuanToCents(raw);
                if (double.tryParse(raw) == null) return '价格只能是数字';
                if (cents < 0) return '价格不能为负';
                if (cents > 10000000) return '价格最多 10 万元';
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),
            DropdownButtonFormField<MarketCategory>(
              key: const Key('mk-category'),
              initialValue: _category,
              decoration: const InputDecoration(labelText: '分类'),
              items: [
                for (final category in MarketCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),
            DropdownButtonFormField<ItemCondition>(
              key: const Key('mk-condition'),
              initialValue: _condition,
              decoration: const InputDecoration(labelText: '成色'),
              items: [
                for (final condition in ItemCondition.values)
                  DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _condition = value);
              },
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('mk-description'),
              controller: _description,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '描述',
                hintText: '用过多久、有什么瑕疵、配件是否齐全',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写描述' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('mk-contact'),
              controller: _contact,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: '联系方式',
                hintText: '手机号或微信号',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? '请留个联系方式' : null,
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
              key: const Key('mk-submit'),
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
