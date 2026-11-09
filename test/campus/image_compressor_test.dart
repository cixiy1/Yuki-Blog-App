import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yuki_blog_app/core/campus/image_compressor.dart';

void main() {
  test('长边超过 1280 的图会被缩到 1280', () {
    final raw = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 2000, height: 1000), quality: 90),
    );

    final out = compressImageBytes(raw);
    final decoded = img.decodeImage(out)!;

    expect(decoded.width, kMaxImageSide);
    expect(decoded.height, 640);
  });

  test('小图不放大，只重编码', () {
    final raw = Uint8List.fromList(
      img.encodePng(img.Image(width: 40, height: 30)),
    );

    final out = compressImageBytes(raw);
    final decoded = img.decodeImage(out)!;

    expect(decoded.width, 40);
    expect(decoded.height, 30);
  });

  test('解码不了的字节原样返回', () {
    final raw = Uint8List.fromList([1, 2, 3, 4]);
    expect(compressImageBytes(raw), raw);
  });

  test('compute 版本在测试环境也能跑通', () async {
    final raw = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 60, height: 60), quality: 90),
    );

    final out = await compute(compressImageBytes, raw);

    expect(out, isNotEmpty);
    expect(img.decodeImage(out), isNotNull);
  });
}
