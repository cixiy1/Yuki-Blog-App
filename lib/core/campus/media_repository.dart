import 'dart:convert';
import 'dart:typed_data';

import '../../models/campus/json_utils.dart';
import '../api/api_client.dart';
import '../api/api_paths.dart';

abstract interface class MediaRepository {
  /// 上传一张已经压好的图片，返回 imageId。
  Future<String> uploadBytes(Uint8List bytes, {String mime = 'image/jpeg'});

  /// 按 id 取回原图字节；不存在返回 null。
  Future<Uint8List?> bytes(String id);
}

class ApiMediaRepository implements MediaRepository {
  ApiMediaRepository(this._api);

  final ApiClient _api;

  /// 内存里留最近用过的若干张，避免反复拉同一张图。
  /// 上限按张数控制，压缩后单张约 100KB，40 张 ≈ 4MB 内存，可接受。
  static const int _cacheLimit = 40;
  final Map<String, Uint8List> _cache = {};

  @override
  Future<String> uploadBytes(Uint8List bytes, {String mime = 'image/jpeg'}) async {
    final result = await _api.post(
      ApiPaths.media,
      body: {'mime': mime, 'dataBase64': base64Encode(bytes)},
    );
    final id = asString(asMap(result)['id']);
    if (id.isEmpty) {
      throw const ApiException(500, 'MEDIA_UPLOAD_FAILED', '图片上传失败');
    }
    _remember(id, bytes);
    return id;
  }

  @override
  Future<Uint8List?> bytes(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    final result = await _api.get(ApiPaths.mediaOne(id));
    final raw = asString(asMap(result)['dataBase64']);
    if (raw.isEmpty) return null;

    Uint8List data;
    try {
      data = base64Decode(raw);
    } catch (_) {
      return null;
    }
    _remember(id, data);
    return data;
  }

  void _remember(String id, Uint8List data) {
    _cache[id] = data;
    if (_cache.length <= _cacheLimit) return;
    // 超限就丢掉最早插入的一条（Map 保序，等价于 FIFO）。
    _cache.remove(_cache.keys.first);
  }
}
