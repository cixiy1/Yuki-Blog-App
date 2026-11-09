import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/campus/image_compressor.dart';
import '../../../core/campus/media_repository.dart';

/// 按 imageId 展示一张图。加载中显示占位，失败显示破图图标。
///
/// 图片不是必现内容，任何异常都只是不显示，不往上抛。
class CampusImage extends StatelessWidget {
  const CampusImage({
    super.key,
    required this.imageId,
    required this.media,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppTheme.radiusMd,
  });

  final String imageId;
  final MediaRepository media;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<Uint8List?>(
          future: media.bytes(imageId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _Placeholder(
                icon: Icons.image_outlined,
                color: Theme.of(context).colorScheme.outlineVariant,
              );
            }
            final data = snapshot.data;
            if (data == null || data.isEmpty) {
              return _Placeholder(
                icon: Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.outline,
              );
            }
            return Image.memory(
              data,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
            );
          },
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: color),
    );
  }
}

/// 把选中的原始字节压成可上传的 JPEG。抽出来是为了测试能绕开真实解码。
Future<Uint8List> compressForUpload(Uint8List raw) =>
    compute(compressImageBytes, raw);
