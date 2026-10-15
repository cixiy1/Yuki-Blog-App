import 'package:http/http.dart' as http;

import 'apk_downloader.dart';

/// 非 IO 平台（Web）没有本地文件系统，应用内下载不可用。
Future<String> downloadToFile(
  String url, {
  required String fileName,
  String? targetDirPath,
  void Function(DownloadProgress progress)? onProgress,
  DownloadCancelToken? cancelToken,
  http.Client? client,
}) async {
  throw DownloadException('当前平台不支持应用内下载，请改用浏览器下载');
}
