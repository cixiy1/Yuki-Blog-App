import 'file_exporter_stub.dart'
    if (dart.library.io) 'file_exporter_io.dart'
    if (dart.library.js_interop) 'file_exporter_web.dart' as impl;

/// 存文本文件的统一签名。原生与 Web 的实现形状一致，测试也可以塞一个假的。
typedef TextFileSaver = Future<String?> Function({
  required String fileName,
  required String content,
});

/// 把一段文本存成文件。
///
/// 原生平台写到临时目录并返回绝对路径（界面把路径显示出来，用户自己去拿）；
/// Web 直接触发浏览器下载并返回 null。两边都加 UTF-8 BOM，
/// 免得 Excel 打开中文变乱码。
Future<String?> saveTextFile({
  required String fileName,
  required String content,
}) =>
    impl.saveTextFile(fileName: fileName, content: content);
