import 'dart:io';

/// 原生平台：写到系统临时目录。返回带 BOM 的 CSV 的绝对路径。
Future<String?> saveTextFile({
  required String fileName,
  required String content,
}) async {
  final dir = await Directory.systemTemp.createTemp('campus_export_');
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString('\uFEFF$content', flush: true);
  return file.path;
}
