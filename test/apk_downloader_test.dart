import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuki_blog_app/core/apk_downloader.dart';

/// 用可控分块 + 可控 Content-Length 的假客户端，替代真实 GitHub 下载。
http.Client _client(
  List<List<int>> chunks, {
  int? contentLength,
  int status = 200,
}) {
  return MockClient.streaming((request, bodyStream) async {
    return http.StreamedResponse(
      Stream.fromIterable(chunks),
      status,
      contentLength: contentLength,
    );
  });
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('apk_dl'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File target() => File('${dir.path}/app.apk');

  group('DownloadProgress', () {
    test('总长已知时给出比例，未知时为 null', () {
      expect(const DownloadProgress(received: 512, total: 1024).fraction, 0.5);
      expect(const DownloadProgress(received: 10, total: 0).fraction, isNull);
      expect(const DownloadProgress(received: 10, total: 0).hasTotal, isFalse);
    });

    test('接收量超过总长时比例封顶为 1', () {
      expect(const DownloadProgress(received: 2048, total: 1024).fraction, 1.0);
    });
  });

  test('分块下载：进度单调递增，文件内容完整', () async {
    final chunks = [
      List<int>.filled(300, 65),
      List<int>.filled(200, 66),
      List<int>.filled(100, 67),
    ];
    const total = 600;
    final received = <int>[];

    final path = await downloadToFile(
      'https://example.com/app.apk',
      fileName: 'app.apk',
      targetDirPath: dir.path,
      client: _client(chunks, contentLength: total),
      onProgress: (p) => received.add(p.received),
    );

    expect(path, '${dir.path}/app.apk');
    expect(target().lengthSync(), total);
    expect(target().readAsBytesSync().first, 65);
    expect(received.first, 0);
    expect(received.last, total);
    for (var i = 1; i < received.length; i++) {
      expect(received[i], greaterThanOrEqualTo(received[i - 1]));
    }
  });

  test('服务端未给 Content-Length 也能下载，进度比例为空', () async {
    final ratios = <double?>[];
    await downloadToFile(
      'https://example.com/app.apk',
      fileName: 'app.apk',
      targetDirPath: dir.path,
      client: _client([
        List<int>.filled(128, 1)
      ]),
      onProgress: (p) => ratios.add(p.fraction),
    );
    expect(target().lengthSync(), 128);
    expect(ratios.every((r) => r == null), isTrue);
  });

  test('HTTP 非 200 抛 DownloadException 且不留残包', () async {
    await expectLater(
      downloadToFile(
        'https://example.com/app.apk',
        fileName: 'app.apk',
        targetDirPath: dir.path,
        client: _client([
          List<int>.filled(10, 1)
        ], status: 404),
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(target().existsSync(), isFalse);
  });

  test('数据不完整（短于 Content-Length）视为失败并清理文件', () async {
    await expectLater(
      downloadToFile(
        'https://example.com/app.apk',
        fileName: 'app.apk',
        targetDirPath: dir.path,
        client: _client([
          List<int>.filled(50, 1)
        ], contentLength: 500),
      ),
      throwsA(isA<DownloadException>()),
    );
    expect(target().existsSync(), isFalse);
  });

  test('取消下载：抛 DownloadCancelledException 并清理文件', () async {
    final token = DownloadCancelToken();
    await expectLater(
      downloadToFile(
        'https://example.com/app.apk',
        fileName: 'app.apk',
        targetDirPath: dir.path,
        client: _client([
          List<int>.filled(256, 1),
          List<int>.filled(256, 2),
        ], contentLength: 512),
        cancelToken: token,
        onProgress: (p) {
          if (p.received > 0) token.cancel();
        },
      ),
      throwsA(isA<DownloadCancelledException>()),
    );
    expect(target().existsSync(), isFalse);
  });

  test('同名旧残包会被覆盖为新内容', () async {
    target().writeAsStringSync('old');
    await downloadToFile(
      'https://example.com/app.apk',
      fileName: 'app.apk',
      targetDirPath: dir.path,
      client: _client([
        List<int>.filled(3, 88)
      ], contentLength: 3),
    );
    expect(target().lengthSync(), 3);
    expect(target().readAsStringSync(), 'XXX');
  });

  test('目标目录不存在时自动创建', () async {
    final nested = '${dir.path}/a/b';
    await downloadToFile(
      'https://example.com/app.apk',
      fileName: 'app.apk',
      targetDirPath: nested,
      client: _client([
        List<int>.filled(4, 1)
      ], contentLength: 4),
    );
    expect(File('$nested/app.apk').existsSync(), isTrue);
  });
}
