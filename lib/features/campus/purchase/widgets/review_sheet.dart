import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/campus/campus_services.dart';
import '../../../../core/campus/credit_engine.dart';
import '../../../../models/campus/review.dart';

/// 打开评价面板。提交成功返回 true。
///
/// 评价同时决定被评人的信用分，所以这里只负责收集和提交，
/// 算分放在服务端（`purchase_handlers` 的 `_createReview`）。
Future<bool> showReviewSheet(
  BuildContext context, {
  required CampusServices services,
  required String taskId,
  required String targetName,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReviewSheet(
      services: services,
      taskId: taskId,
      targetName: targetName,
    ),
  );
  return result == true;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.services,
    required this.taskId,
    required this.targetName,
  });

  final CampusServices services;
  final String taskId;
  final String targetName;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _comment = TextEditingController();
  final Set<String> _tags = {};
  int _stars = 5;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.services.purchases.submitReview(
        widget.taskId,
        stars: _stars,
        tags: _tags.toList(),
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '提交失败：$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.spacingLg,
        0,
        AppTheme.spacingLg,
        AppTheme.spacingLg + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '评价 ${widget.targetName}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: Key('rv-star-$i'),
                    onPressed: () => setState(() => _stars = i),
                    iconSize: 32,
                    icon: Icon(
                      i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i <= _stars ? scheme.tertiary : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
            Center(
              child: Text(
                '$_stars 星 · ${describeCreditDelta(_stars)}',
                key: const Key('rv-credit-hint'),
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text('印象标签（选填）', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTheme.spacingXs),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingXs,
              children: [
                for (final tag in ReviewTags.all)
                  FilterChip(
                    label: Text(tag),
                    selected: _tags.contains(tag),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _tags.add(tag);
                        } else {
                          _tags.remove(tag);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            TextField(
              key: const Key('rv-comment'),
              controller: _comment,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '说两句（选填）',
                hintText: '对方哪些地方做得好 / 哪里需要改进',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppTheme.spacingSm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('rv-submit'),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交评价'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
