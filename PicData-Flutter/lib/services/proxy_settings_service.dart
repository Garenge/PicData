import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 持久化 HTTP 代理；仅由设置页写入，[NetClient] 在变更时重建客户端以应用。
///
/// 使用独立的 host / port 存储，避免 `host:port` 与 IPv6 混淆。
class ProxySettingsService {
  ProxySettingsService._internal();

  static final ProxySettingsService instance = ProxySettingsService._internal();

  static const String _hostKey = 'net_proxy_host';
  static const String _portKey = 'net_proxy_port';
  /// 旧版单字段，启动时迁移后删除。
  static const String _legacyHostPortKey = 'net_proxy_host_port';

  static const String kDefaultProxyHost = '127.0.0.1';
  static const int kDefaultProxyPort = 7897;

  final ValueNotifier<String> proxyHostNotifier = ValueNotifier<String>('');
  final ValueNotifier<int?> proxyPortNotifier = ValueNotifier<int?>(null);

  String get proxyHost => proxyHostNotifier.value;
  int? get proxyPort => proxyPortNotifier.value;

  /// 是否使用代理（主机非空且端口在有效范围内）。
  bool get isProxyEnabled {
    final h = proxyHostNotifier.value.trim();
    final p = proxyPortNotifier.value;
    return h.isNotEmpty && p != null && p >= 1 && p <= 65535;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyHostPortIfNeeded(prefs);

    final host = prefs.getString(_hostKey)?.trim() ?? '';
    final hasPort = prefs.containsKey(_portKey);
    final port = hasPort ? prefs.getInt(_portKey) : null;

    proxyHostNotifier.value = host;
    proxyPortNotifier.value = port;
  }

  Future<void> _migrateLegacyHostPortIfNeeded(SharedPreferences prefs) async {
    if (!prefs.containsKey(_legacyHostPortKey)) {
      return;
    }
    final raw = prefs.getString(_legacyHostPortKey)?.trim() ?? '';
    if (raw.isEmpty) {
      await prefs.remove(_legacyHostPortKey);
      await prefs.remove(_hostKey);
      await prefs.remove(_portKey);
      return;
    }
    final idx = raw.lastIndexOf(':');
    if (idx <= 0 || idx >= raw.length - 1) {
      await prefs.remove(_legacyHostPortKey);
      return;
    }
    final host = raw.substring(0, idx).trim();
    final port = int.tryParse(raw.substring(idx + 1));
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      await prefs.remove(_legacyHostPortKey);
      return;
    }
    await prefs.setString(_hostKey, host);
    await prefs.setInt(_portKey, port);
    await prefs.remove(_legacyHostPortKey);
  }

  Future<void> setProxyHostAndPort({required String host, required int? port}) async {
    final h = host.trim();
    final prefs = await SharedPreferences.getInstance();

    if (h.isEmpty || port == null) {
      await prefs.remove(_hostKey);
      await prefs.remove(_portKey);
      proxyHostNotifier.value = '';
      proxyPortNotifier.value = null;
      return;
    }

    await prefs.setString(_hostKey, h);
    await prefs.setInt(_portKey, port);
    proxyHostNotifier.value = h;
    proxyPortNotifier.value = port;
  }

  /// 供 `dart:io` [HttpClient.findProxy] 绑定的单行结果（仅反映当前设置）。
  String get httpProxyPacDirective {
    if (kIsWeb) {
      return 'DIRECT';
    }
    if (!isProxyEnabled) {
      return 'DIRECT';
    }
    final host = proxyHostNotifier.value.trim();
    final port = proxyPortNotifier.value!;
    final authority = _proxyAuthority(host, port);
    return 'PROXY $authority;';
  }

  /// `host` + `port` → PAC 中的 `host:port`（IPv6 加方括号）。
  static String _proxyAuthority(String host, int port) {
    final h = host.trim();
    if (h.contains(':') && !h.startsWith('[')) {
      return '[$h]:$port';
    }
    return '$h:$port';
  }

  static bool isValidHost(String host) {
    final t = host.trim();
    return t.isNotEmpty && t.length <= 253;
  }

  static bool isValidPort(int? port) {
    if (port == null) {
      return false;
    }
    return port >= 1 && port <= 65535;
  }

  /// 直连：主机、端口都未有效填写。
  static bool isDirect(String host, int? port) {
    return host.trim().isEmpty || port == null;
  }
}
