import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 上传前统一压缩：最长边不超过 [kMaxImageSide]，JPEG 质量 [kJpegQuality]。
///
/// 单张压完大约 80–150KB。Web 端 localStorage 只有 5MB，
/// 不压直接 base64 会几下就把配额吃掉。
const int kMaxImageSide = 1280;
const int kJpegQuality = 70;

/// 纯函数版本，供 `compute` 在后台 isolate 里跑（Web 上退化为同步）。
Uint8List compressImageBytes(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;

  var output = decoded;
  if (decoded.width > kMaxImageSide || decoded.height > kMaxImageSide) {
    output = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: kMaxImageSide)
        : img.copyResize(decoded, height: kMaxImageSide);
  }
  return Uint8List.fromList(img.encodeJpg(output, quality: kJpegQuality));
}
