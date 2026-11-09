import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yuki_blog_app/core/api/api_client.dart';
import 'package:yuki_blog_app/core/api/http_api_client.dart';

/// 契约测试：锁住「走真 HTTP 时」的行为。
/// Mock 后端必须遵守同一套语义，所以将来切过去不会出现调用点要改。
void main() {
  late List<http.Request> captured;
  late HttpApiClient api;

  setUp(() {
    captured = [];
    final client = MockClient((request) async {
      captured.add(request);
      return http.Response(
        jsonEncode({'ok': true}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    api = HttpApiClient(baseUrl: 'https://example.com/api', client: client);
  });

  tearDown(() => api.dispose());

  test('GET 把 query 拼到 URL 上', () async {
    await api.request('GET', '/market', query: {'category': 'book', 'page': '2'});

    final req = captured.single;
    expect(req.method, 'GET');
    expect(req.url.path, '/api/market');
    expect(req.url.queryParameters['category'], 'book');
    expect(req.url.queryParameters['page'], '2');
  });

  test('POST 用 JSON 提交 body 并声明 content-type', () async {
    await api.request('POST', '/market', body: {'title': '台灯', 'priceCents': 2000});

    final req = captured.single;
    expect(req.method, 'POST');
    expect(req.headers['content-type'], contains('application/json'));
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['title'], '台灯');
    expect(body['priceCents'], 2000);
  });

  test('设了 authToken 就带 Authorization 头', () async {
    api.authToken = 'mock.v1.u_1.1.abcd1234';
    await api.request('GET', '/auth/me');

    expect(
      captured.single.headers['authorization'],
      'Bearer mock.v1.u_1.1.abcd1234',
    );
  });

  test('非 2xx 抛 ApiException 并带上 code / message / fieldErrors', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'VALIDATION_FAILED',
            'message': '提交内容校验未通过',
            'fieldErrors': {'studentId': '学号需 8-12 位数字'},
          },
        }),
        422,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final failing = HttpApiClient(
      baseUrl: 'https://example.com/api',
      client: client,
    );
    addTearDown(failing.dispose);

    try {
      await failing.request('POST', '/auth/register');
      fail('应该抛 ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 422);
      expect(e.code, 'VALIDATION_FAILED');
      expect(e.message, '提交内容校验未通过');
      expect(e.fieldErrors['studentId'], '学号需 8-12 位数字');
      expect(e.isValidation, isTrue);
    }
  });
}
