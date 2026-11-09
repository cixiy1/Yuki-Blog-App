import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web：生成 Blob 走浏览器下载，返回 null 表示「已经交给浏览器了」。
Future<String?> saveTextFile({
  required String fileName,
  required String content,
}) async {
  final bytes = utf8.encode('\uFEFF$content');
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return null;
}
