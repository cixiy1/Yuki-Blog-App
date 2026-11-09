import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/campus/media_repository.dart';
import 'campus_image.dart';

/// 选图回调。默认实现走系统相册，测试里可以直接塞字节。
typedef ImageBytesPicker = Future<List<Uint8List>> Function();

/// 多图选择 + 缩略预览 + 删除。
///
/// 选完立刻压缩上传，返回的是 imageId 列表——表单只存 id，不存字节。
class ImagePickerField extends StatefulWidget {
  const ImagePickerField({
    super.key,
    required this.imageIds,
    required this.onChanged,
    required this.media,
    this.max = 3,
    this.pickBytes,
    this.label = '图片',
  });

  final List<String> imageIds;
  final ValueChanged<List<String>> onChanged;
  final MediaRepository media;
  final int max;
  final ImageBytesPicker? pickBytes;
  final String label;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  bool _busy = false;
  String? _error;

  Future<List<Uint8List>> _defaultPick() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    final result = <Uint8List>[];
    for (final file in files) {
      result.add(await file.readAsBytes());
    }
    return result;
  }

  Future<void> _pick() async {
    if (_busy) return;
    final remaining = widget.max - widget.imageIds.length;
    if (remaining <= 0) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final picker = widget.pickBytes ?? _defaultPick;
      final rawList = await picker();
      final added = <String>[];

      for (final raw in rawList.take(remaining)) {
        final compressed = await compressForUpload(raw);
        final id = await widget.media.uploadBytes(compressed);
        added.add(id);
      }

      if (!mounted) return;
      if (added.isNotEmpty) {
        widget.onChanged([...widget.imageIds, ...added]);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '图片处理失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _remove(String id) {
    widget.onChanged([
      for (final existing in widget.imageIds)
        if (existing != id) existing,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label, style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppTheme.spacingSm),
            Text(
              '${widget.imageIds.length}/${widget.max}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: [
            for (final id in widget.imageIds)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CampusImage(
                    imageId: id,
                    media: widget.media,
                    width: 76,
                    height: 76,
                  ),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: GestureDetector(
                      onTap: () => _remove(id),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: scheme.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            if (widget.imageIds.length < widget.max)
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                onTap: _busy ? null : _pick,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 22, color: scheme.onSurfaceVariant),
                            const SizedBox(height: 2),
                            Text(
                              '选择图片',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        if (widget.max > 0) ...[
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            '最多 ${widget.max} 张，会自动压缩到 1280px 以内',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }
}
