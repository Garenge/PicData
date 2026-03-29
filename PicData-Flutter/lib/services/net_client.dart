import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// 控制 [NetClient.getText] 控制台输出粒度（详情页调试用 `full`，批量爬取用 `compact` / `off`）。
enum NetTextRequestLogMode {
  /// 请求前、响应后各一行（含 headers）。
  full,

  /// 仅一行：`status bytes path?query`。
  compact,

  /// 不打印。
  off,
}

/// 简单的网络请求工具类，后续可以统一在这里加超时、通用 Header、重试等逻辑
class NetClient {
  NetClient._internal() {
    if (kIsWeb) {
      // Web 环境不支持 dart:io / HttpClient，这里直接使用默认 http.Client。
      _client = http.Client();
    } else {
      final httpClient = HttpClient();
      // 在 macOS 上，统一通过本机代理 127.0.0.1:7897 转发请求。
      // 其他平台暂时直连，后续再按需扩展。
      httpClient.findProxy = (uri) {
        if (Platform.isMacOS) {
          return 'PROXY 127.0.0.1:7897;';
        }
        return 'DIRECT';
      };
      _client = IOClient(httpClient);
    }
  }

  static final NetClient instance = NetClient._internal();

  late final http.Client _client;

  Future<String> getText(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
    NetTextRequestLogMode logMode = NetTextRequestLogMode.full,
  }) async {
    final uri = Uri.parse(url);
    if (logMode == NetTextRequestLogMode.full) {
      // ignore: avoid_print
      print(
        'NetClient.getText -> GET $uri, timeout=${timeout.inSeconds}s, '
        'headers=${headers ?? const <String, String>{}}',
      );
    }

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);

      if (logMode == NetTextRequestLogMode.full) {
        // ignore: avoid_print
        print(
          'NetClient.getText <- status=${response.statusCode}, '
          'url=$uri, bodyBytes=${response.bodyBytes.length}',
        );
      } else if (logMode == NetTextRequestLogMode.compact) {
        final pathQ = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
        // ignore: avoid_print
        print(
          'NetClient.getText  ${response.statusCode}  '
          '${response.bodyBytes.length}B  $pathQ',
        );
      }

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

  /// 下载二进制内容（图片等）。默认不打日志，避免队列 B 刷屏。
  Future<List<int>> getBytes(
    String url, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 60),
    NetTextRequestLogMode logMode = NetTextRequestLogMode.off,
  }) async {
    final uri = Uri.parse(url);
    if (logMode == NetTextRequestLogMode.full) {
      // ignore: avoid_print
      print(
        'NetClient.getBytes -> GET $uri, timeout=${timeout.inSeconds}s, '
        'headers=${headers ?? const <String, String>{}}',
      );
    }

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);

      if (logMode == NetTextRequestLogMode.full) {
        // ignore: avoid_print
        print(
          'NetClient.getBytes <- status=${response.statusCode}, '
          'url=$uri, bodyBytes=${response.bodyBytes.length}',
        );
      } else if (logMode == NetTextRequestLogMode.compact) {
        final pathQ = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
        // ignore: avoid_print
        print(
          'NetClient.getBytes  ${response.statusCode}  '
          '${response.bodyBytes.length}B  $pathQ',
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      throw HttpException(
        'Request failed: ${response.statusCode}',
        uri: uri,
      );
    } on Exception catch (e, st) {
      // ignore: avoid_print
      print('NetClient.getBytes ERROR for $uri');
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

