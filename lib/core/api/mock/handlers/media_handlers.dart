import 'dart:convert';

import '../../api_paths.dart';
import '../mock_request.dart';
import '../mock_router.dart';
import '../mock_support.dart';

/// 单张图片的最大 base64 长度。约 1.5MB 原图，压过之后远小于这个数。
/// 设上限是为了别让一张图就把 Web 的 localStorage 配额吃掉一半。
const int _maxBase64Length = 2 * 1024 * 1024;

void registerMediaHandlers(MockRouter r) {
  r.on('POST', ApiPaths.media, _upload);
  r.on('GET', '/media/:id', _read);
}

Object? _upload(MockRequest req) {
  final user = requireUser(req);
  final mime = requiredString(req.json, 'mime', label: '图片类型', maxLength: 64);
  final data = requiredString(req.json, 'dataBase64',
      label: '图片内容', maxLength: _maxBase64Length);
  if (!mime.startsWith('image/')) {
    invalid({'mime': '只支持图片'});
  }

  return req.backend.mutate((db) {
    final id = db.nextId('md');
    db.media.add({
      'id': id,
      'mime': mime,
      'dataBase64': data,
      'uploaderId': user.id,
      'size': (data.length * 3) ~/ 4,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    return {'id': id, 'mime': mime, 'size': (data.length * 3) ~/ 4};
  });
}

Object? _read(MockRequest req) {
  requireUser(req);
  final row = findRow(req.backend.db.media, req.param('id'), what: '图片');
  return {
    'id': row['id'],
    'mime': row['mime'],
    'dataBase64': row['dataBase64'],
  };
}

/// 给测试和种子用：把一段字节转成上传用的 base64。
String encodeImage(List<int> bytes) => base64Encode(bytes);
