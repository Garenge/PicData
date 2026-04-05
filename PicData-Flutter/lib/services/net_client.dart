import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'package:pic_data/services/proxy_settings_service.dart';

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
///
/// 代理仅来自 [ProxySettingsService]（设置页持久化）；不在单次请求路径里解析或探测代理，
/// 设置变更时通过 [attachProxySettingsListener] 重建底层 [HttpClient]。
class NetClient {
  NetClient._internal() {
    if (kIsWeb) {
      _client = http.Client();
    } else {
      _syncDirectiveFromSettings();
      _client = _createIoClient();
    }
  }

  static final NetClient instance = NetClient._internal();

  late http.Client _client;

  /// 与 [ProxySettingsService.httpProxyPacDirective] 同步时的快照，仅用于绑定 `findProxy`。
  String _proxyDirective = 'DIRECT';

  static bool _proxyListenerAttached = false;

  /// 须在 [ProxySettingsService.load] 之后调用一次。
  static void attachProxySettingsListener() {
    if (kIsWeb || _proxyListenerAttached) {
      return;
    }
    _proxyListenerAttached = true;
    ProxySettingsService.instance.proxyHostNotifier.addListener(
      instance._onProxySettingsChanged,
    );
    ProxySettingsService.instance.proxyPortNotifier.addListener(
      instance._onProxySettingsChanged,
    );
  }

  void _onProxySettingsChanged() {
    _rebuildIoClient();
  }

  void _syncDirectiveFromSettings() {
    _proxyDirective = ProxySettingsService.instance.httpProxyPacDirective;
  }

  http.Client _createIoClient() {
    final httpClient = HttpClient();
    httpClient.findProxy = (_) => _proxyDirective;
    return IOClient(httpClient);
  }

  void _rebuildIoClient() {
    if (kIsWeb) {
      return;
    }
    _syncDirectiveFromSettings();
    final http.Client old = _client;
    _client = _createIoClient();
    old.close();
  }

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
