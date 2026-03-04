import 'dart:convert';

import 'package:http/http.dart' as http;

/// 简单的网络请求工具类，后续可以统一在这里加超时、通用 Header、重试等逻辑
class NetClient {
  NetClient._internal();

  static final NetClient instance = NetClient._internal();

  Future<String> getText(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse(url);
    // ignore: avoid_print
    print(
      'NetClient.getText -> GET $uri, timeout=${timeout.inSeconds}s, '
      'headers=${headers ?? const <String, String>{}}',
    );

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeout);

      // ignore: avoid_print
      print(
        'NetClient.getText <- status=${response.statusCode}, '
        'url=$uri, bodyBytes=${response.bodyBytes.length}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 尝试用 UTF-8 解码，避免部分站点乱码
        return utf8.decode(response.bodyBytes);
      }

      throw HttpException(
        'Request failed: ${response.statusCode}',
        uri: uri,
      );
    } on Exception catch (e, st) {
      // 这里捕获所有异常，详细打印类型和堆栈，方便排查网络/系统问题
      // ignore: avoid_print
      print('NetClient.getText ERROR for $uri');
      // ignore: avoid_print
      print('  errorType=${e.runtimeType}');
      // ignore: avoid_print
      print('  error=$e');
      // ignore: avoid_print
      print('  stackTrace=$st');
      rethrow;
    }
  }
}

class HttpException implements Exception {
  HttpException(this.message, {this.uri});

  final String message;
  final Uri? uri;

  @override
  String toString() {
    if (uri == null) return 'HttpException: $message';
    return 'HttpException: $message, uri: $uri';
  }
}

