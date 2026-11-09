import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'json_store_base.dart';

/// 原生实现：写在 `<应用文档目录>/campus/<key>.json`。
///
/// 保存用「写临时文件 → rename 覆盖」，同目录 rename 是原子的，
/// 进程中途被杀不会留下半截 JSON。
class FileJsonStore implements JsonStore {
  FileJsonStore({Future<Directory>? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory();

  final Future<Directory> _directory;

  Future<Directory> get _dir async {
    final base = await _directory;
    final dir = Directory('${base.path}/campus');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileOf(String key) async => File('${(await _dir).path}/$key.json');

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    try {
      final file = await _fileOf(key);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      // 文件损坏 / 权限问题一律当作「没有」，让上层走重新播种。
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final file = await _fileOf(key);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete(String key) async {
    final file = await _fileOf(key);
    if (await file.exists()) await file.delete();
  }

  @override
  bool get isPersistent => true;
}

JsonStore createJsonStore() => FileJsonStore();
