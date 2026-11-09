import 'dart:async';

import '../api_client.dart';
import 'mock_request.dart';

class _ParamRoute {
  _ParamRoute(this.method, this.pattern, this.handler)
      : segments = pattern.split('/');

  final String method;
  final String pattern;
  final List<String> segments;
  final MockHandler handler;

  /// 段数相同且每段要么相等、要么是 `:name` 才命中。
  Map<String, String>? match(String reqMethod, List<String> reqSegments) {
    if (reqMethod != method) return null;
    if (reqSegments.length != segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < segments.length; i++) {
      final patternSeg = segments[i];
      if (patternSeg.startsWith(':')) {
        params[patternSeg.substring(1)] = reqSegments[i];
      } else if (patternSeg != reqSegments[i]) {
        return null;
      }
    }
    return params;
  }
}

/// Mock 后端的路径路由表。
///
/// 静态路径优先于带参路径——否则 `/activities/pending-review` 会被
/// `/activities/:id` 抢走，变成「活动 id 叫 pending-review」。
class MockRouter {
  final Map<String, MockHandler> _exact = {};
  final List<_ParamRoute> _param = [];

  void on(String method, String pattern, MockHandler handler) {
    if (pattern.contains(':')) {
      _param.add(_ParamRoute(method, pattern, handler));
    } else {
      _exact['$method $pattern'] = handler;
    }
  }

  int get routeCount => _exact.length + _param.length;

  FutureOr<Object?> dispatch(MockRequest req) {
    final exact = _exact['${req.method} ${req.path}'];
    if (exact != null) return exact(req);

    final segments = req.path.split('/');
    for (final route in _param) {
      final params = route.match(req.method, segments);
      if (params != null) return route.handler(req.withParams(params));
    }

    // 同一路径存在但方法不对 → 405，比 404 更有诊断价值。
    for (final key in _exact.keys) {
      if (key.endsWith(' ${req.path}')) {
        throw ApiException(405, 'METHOD_NOT_ALLOWED', '该接口不支持 ${req.method}');
      }
    }
    throw const ApiException(404, 'NOT_FOUND', '接口不存在');
  }
}
