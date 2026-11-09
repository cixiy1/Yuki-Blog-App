UnsupportedError _unsupported() =>
    UnsupportedError('当前平台不支持导出文件');

/// 其余平台：显式失败，别让调用方以为存成功了。
Future<String?> saveTextFile({
  required String fileName,
  required String content,
}) async =>
    throw _unsupported();
