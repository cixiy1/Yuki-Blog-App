import 'package:http/http.dart' as http;

import 'apk_downloader_stub.dart'
    if (dart.library.io) 'apk_downloader_io.dart' as impl;

/// 下载进度快照。
class DownloadProgress {
  const DownloadProgress({required this.received, required this.total});

  /// 已接收字节数。
  final int received;

  /// 总字节数；0 表示服务端未给出 Content-Length，进度不可知。
  final int total;

  bool get hasTotal => total > 0;

  /// 0.0~1.0 的进度；总长度未知时为 null（界面显示不确定进度条）。
  double? get fraction => hasTotal ? (received / total).clamp(0.0, 1.0) : null;
}

/// 取消令牌：下载过程中调用 [cancel] 即可中止。
class DownloadCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// 下载失败（网络、状态码、写入等）。
class DownloadException implements Exception {
  DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 用户主动取消。
class DownloadCancelledException extends DownloadException {
  DownloadCancelledException() : super('已取消下载');
}

/// 把远端文件流式下载到本地，返回保存后的完整路径。
///
/// [fileName] 保存的文件名；[targetDirPath] 省略时写入应用缓存目录下的
/// `updates/`（在 open_filex 声明的 FileProvider `cache-path` 覆盖范围内，
/// 安装器可以直接读取）；[onProgress] 每次收到数据块回调一次。
Future<String> downloadToFile(
  String url, {
  required String fileName,
  String? targetDirPath,
  void Function(DownloadProgress progress)? onProgress,
  DownloadCancelToken? cancelToken,
  http.Client? client,
}) {
  return impl.downloadToFile(
    url,
    fileName: fileName,
    targetDirPath: targetDirPath,
    onProgress: onProgress,
    cancelToken: cancelToken,
    client: client,
  );
}
