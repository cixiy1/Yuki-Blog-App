import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuki_blog_app/core/update_service.dart';

void main() {
  // PackageInfo 在测试环境需要 mock 平台渠道
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => {
              'appName': 'Yuki Blog',
              'packageName': 'com.yiyu14.yuki_blog_app',
              'version': '1.0.0',
              'buildNumber': '1',
            });
  });

  group('UpdateService.isNewer 版本比较', () {
    test('标准语义化版本', () {
      expect(UpdateService.isNewer('v1.1.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('v1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('v2.0.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewer('v1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewer('v1.0.0', '1.0.1'), isFalse);
      expect(UpdateService.isNewer('1.1.0+2', '1.1.0'), isFalse);
    });

    test('格式容错', () {
      expect(UpdateService.isNewer('  V1.2.0  ', '1.1.0'), isTrue);
      expect(UpdateService.isNewer('v1.x.0', '1.1.0'), isFalse);
    });
  });

  group('checkForUpdate 拉取 GitHub Release', () {
    const fakeRelease = '''
{
  "tag_name": "v1.2.0",
  "body": "修复若干问题",
  "html_url": "https://github.com/cixiy1/Yuki-Blog-App/releases/tag/v1.2.0",
  "assets": [
    {"name": "yuki-blog-v1.2.0.apk",
     "browser_download_url": "https://github.com/cixiy1/Yuki-Blog-App/releases/download/v1.2.0/yuki-blog-v1.2.0.apk"}
  ]
}
''';

    test('远端版本更新时返回 Release 信息', () async {
      final service = UpdateService(
        // 中文 Release 说明必须走 UTF-8 bytes（Response 默认 latin1 会抛异常）
        client: MockClient(
            (req) async => http.Response.bytes(utf8.encode(fakeRelease), 200)),
      );
      // PackageInfo 在测试环境返回 0.0.0，v1.2.0 判定为更新
      final release = await service.checkForUpdate();
      expect(release, isNotNull);
      expect(release!.tagName, 'v1.2.0');
      expect(release.apkUrl, contains('.apk'));
      service.dispose();
    });

    test('HTTP 失败时静默返回 null', () async {
      final service = UpdateService(
        client: MockClient((req) async => http.Response('rate limit', 403)),
      );
      expect(await service.checkForUpdate(), isNull);
      service.dispose();
    });
  });
}
