import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/campus_services.dart';
import '../../../core/campus/purchase_repository.dart';
import '../../../models/campus/purchase_task.dart';
import '../shared/campus_format.dart';
import '../shared/campus_sub_page.dart';

/// 清单里的一行，带自己的两个输入框。
class _ItemDraft {
  _ItemDraft({String name = '', String qty = '1'})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: qty);

  final TextEditingController name;
  final TextEditingController qty;

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

/// 发布一条代买 / 跑腿。
class PurchaseEditorPage extends StatefulWidget {
  const PurchaseEditorPage({super.key, required this.services});

  final CampusServices services;

  @override
  State<PurchaseEditorPage> createState() => _PurchaseEditorPageState();
}

class _PurchaseEditorPageState extends State<PurchaseEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  final List<_ItemDraft> _items = [_ItemDraft()];

  late DateTime _deadline = DateTime.now()
      .add(const Duration(hours: 3))
      .copyWith(second: 0, millisecond: 0, microsecond: 0);
  PaymentMethod _payment = PaymentMethod.wechat;
  bool _schoolWide = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _from.dispose();
    _to.dispose();
    _amount.dispose();
    _note.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    if (_items.length >= 10) {
      setState(() => _error = '最多写 10 样东西');
      return;
    }
    setState(() => _items.add(_ItemDraft()));
  }

  void _removeItem(int index) {
    if (_items.length == 1) {
      setState(() => _error = '至少要写一样东西');
      return;
    }
    setState(() {
      _items.removeAt(index).dispose();
      _error = null;
    });
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
      await widget.services.purchases.create(
        title: _title.text.trim(),
        fromPlace: _from.text.trim(),
        toPlace: _to.text.trim(),
        items: [
          for (final item in _items)
            PurchaseDraftItem(
              name: item.name.text.trim(),
              qty: int.tryParse(item.qty.text.trim()) ?? 1,
            ),
        ],
        amountCents: yuanToCents(_amount.text),
        paymentMethod: _payment,
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
      title: '发布代买',
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
              key: const Key('pu-title'),
              controller: _title,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '如 帮带两杯奶茶',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写标题' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('pu-from'),
              controller: _from,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '出发地点',
                hintText: '如 一饭二楼奶茶店',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写出发地点' : null,
            ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('pu-to'),
              controller: _to,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '送达地点',
                hintText: '如 3栋412',
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? '请填写送达地点' : null,
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              children: [
                Text(
                  '要买的东西',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  '${_items.length}/10',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  key: const Key('pu-add-item'),
                  onPressed: _addItem,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('加一样'),
                ),
              ],
            ),
            for (var i = 0; i < _items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: Key('pu-item-name-$i'),
                        controller: _items[i].name,
                        decoration: const InputDecoration(
                          labelText: '名称',
                          isDense: true,
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? '写一下是什么' : null,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    SizedBox(
                      width: 64,
                      child: TextFormField(
                        key: Key('pu-item-qty-$i'),
                        controller: _items[i].qty,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '数量',
                          isDense: true,
                        ),
                        validator: (v) {
                          final parsed = int.tryParse((v ?? '').trim());
                          if (parsed == null || parsed < 1) return '≥1';
                          if (parsed > 99) return '≤99';
                          return null;
                        },
                      ),
                    ),
                    IconButton(
                      key: Key('pu-remove-item-$i'),
                      onPressed: () => _removeItem(i),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      tooltip: '删掉这一行',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppTheme.spacingSm),
            TextFormField(
              key: const Key('pu-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '预计金额',
                hintText: '按实际花费填，线下结算',
                prefixText: '¥ ',
              ),
              validator: (v) {
                final raw = (v ?? '').trim();
                if (raw.isEmpty) return '请填写金额';
                if (double.tryParse(raw) == null) return '金额只能是数字';
                if (yuanToCents(raw) > 1000000) return '金额最多 1 万元';
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text('收款方式', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTheme.spacingXs),
            SegmentedButton<PaymentMethod>(
              segments: [
                for (final method in PaymentMethod.values)
                  ButtonSegment(value: method, label: Text(method.label)),
              ],
              selected: {_payment},
              onSelectionChanged: (values) =>
                  setState(() => _payment = values.first),
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
              key: const Key('pu-note'),
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                hintText: '少冰、不要珍珠之类',
              ),
            ),
            SwitchListTile(
              key: const Key('pu-scope'),
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
              key: const Key('pu-submit'),
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
