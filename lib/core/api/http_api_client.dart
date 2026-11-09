import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// 真后端实现。本期不启用，但接口契约与 Mock 完全一致——
/// 将来只要把 `CampusServices` 里的构造换成
/// `HttpApiClient(baseUrl: 'https://api.example.com')` 就能切过去。
class HttpApiClient implements ApiClient {
  HttpApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  @override
  String? authToken;

  @override
  void Function()? onUnauthorized;

  @override
  Future<Object?> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );

    final req = http.Request(method, uri);
    req.headers['accept'] = 'application/json';
    if (headers != null) req.headers.addAll(headers);
    if (body != null) {
      req.headers['content-type'] = 'application/json; charset=utf-8';
      req.bodyBytes = utf8.encode(jsonEncode(body));
    }
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      req.headers['authorization'] = 'Bearer $token';
    }

    late final http.Response resp;
    try {
      final streamed = await _client.send(req).timeout(timeout);
      resp = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(408, 'TIMEOUT', '请求超时，请检查网络');
    } catch (e) {
      throw ApiException(0, 'NETWORK_ERROR', '网络异常：$e');
    }

    final text = utf8.decode(resp.bodyBytes, allowMalformed: true);
    Object? decoded;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = text;
      }
    }

    if (resp.statusCode >= 400) {
      final err = ApiException.fromPayload(resp.statusCode, decoded);
      if (err.isUnauthorized) onUnauthorized?.call();
      throw err;
    }
    return decoded;
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
