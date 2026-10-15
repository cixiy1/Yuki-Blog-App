import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'apk_downloader.dart';

/// 建立连接的超时时间；一旦开始接收数据就不再限时
/// （安装包有几十 MB，慢网络下整体耗时可能远超这个值）。
const Duration _connectTimeout = Duration(seconds: 20);

Future<String> downloadToFile(
  String url, {
  required String fileName,
  String? targetDirPath,
  void Function(DownloadProgress progress)? onProgress,
  DownloadCancelToken? cancelToken,
  http.Client? client,
}) async {
  final ownsClient = client == null;
  final httpClient = client ?? http.Client();
  final dir = targetDirPath != null
      ? Directory(targetDirPath)
      : Directory('${(await getTemporaryDirectory()).path}/updates');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final file = File('${dir.path}/$fileName');
  // 上一次下载中断留下的残包可能与新版同名，先清掉避免覆盖写入出错。
  if (file.existsSync()) file.deleteSync();

  try {
    final http.StreamedResponse resp;
    try {
      resp = await httpClient
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(_connectTimeout);
    } on TimeoutException {
      throw DownloadException('连接超时，请检查网络后重试');
    } on SocketException catch (e) {
      throw DownloadException('网络不可用：${e.message}');
    }

    if (resp.statusCode != 200) {
      throw DownloadException('下载失败（服务器返回 ${resp.statusCode}）');
    }

    final total = resp.contentLength ?? 0;
    var received = 0;
    onProgress?.call(DownloadProgress(received: 0, total: total));

    final sink = file.openWrite();
    try {
      await for (final chunk in resp.stream) {
        if (cancelToken?.isCancelled ?? false) {
          throw DownloadCancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(DownloadProgress(received: received, total: total));
      }
      await sink.flush();
      await sink.close();

      if (received == 0) throw DownloadException('下载内容为空，请稍后重试');
      if (total > 0 && received < total) {
        throw DownloadException('下载不完整（$received/$total 字节），请重试');
      }
      return file.path;
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {
        // 流已关闭，忽略
      }
      rethrow;
    }
  } catch (_) {
    // 失败/取消都不留半截文件，避免安装器读到损坏的包。
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // 清理失败不影响把原始错误抛给调用方
    }
    rethrow;
  } finally {
    if (ownsClient) httpClient.close();
  }
}
