import 'dart:convert';

class PicNetConfig {
  PicNetConfig({required this.hosts, required this.globalSearchKeys});

  factory PicNetConfig.fromJson(Map<String, dynamic> json) {
    final hostsJson = json['hosts'] as List<dynamic>? ?? [];
    final hosts = hostsJson
        .whereType<Map<String, dynamic>>()
        .map(PicHost.fromJson)
        .toList();

    final searchKeysJson = json['searchKeys'] as List<dynamic>? ?? [];
    final globalSearchKeys = searchKeysJson
        .whereType<String>()
        .toList();

    return PicNetConfig(
      hosts: hosts,
      globalSearchKeys: globalSearchKeys,
    );
  }

  final List<PicHost> hosts;
  final List<String> globalSearchKeys;
}

class PicHost {
  PicHost({
    required this.title,
    this.sourceType,
    this.hostUrl,
    this.referer,
    this.urls = const [],
    this.tagsUrl,
    this.searchFormat,
    this.searchKeys = const [],
    this.searchEncode,
    this.mark,
    this.tips,
    this.prepared,
  });

  factory PicHost.fromJson(Map<String, dynamic> json) {
    final urlsJson = json['urls'] as List<dynamic>? ?? [];
    final urls = urlsJson
        .whereType<Map<String, dynamic>>()
        .map(PicUrl.fromJson)
        .toList();

    final searchKeysJson = json['searchKeys'] as List<dynamic>? ?? [];
    final searchKeys = searchKeysJson
        .whereType<String>()
        .toList();

    return PicHost(
      title: json['title'] as String? ?? '',
      sourceType: json['sourceType'] as int?,
      hostUrl: json['HOST_URL'] as String?,
      referer: json['referer'] as String?,
      urls: urls,
      tagsUrl: json['tagsUrl'] as String?,
      searchFormat: json['searchFormat'] as String?,
      searchKeys: searchKeys,
      searchEncode: json['searchEncode'] as bool?,
      mark: json['mark'] as String?,
      tips: json['tips'] as String?,
      prepared: json['prepared'] as bool?,
    );
  }

  final String title;
  final int? sourceType;
  final String? hostUrl;
  final String? referer;
  final List<PicUrl> urls;
  final String? tagsUrl;
  final String? searchFormat;
  final List<String> searchKeys;
  final bool? searchEncode;
  final String? mark;
  final String? tips;
  final bool? prepared;
}

class PicUrl {
  PicUrl({required this.url, required this.title});

  factory PicUrl.fromJson(Map<String, dynamic> json) {
    return PicUrl(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }

  final String url;
  final String title;
}

PicNetConfig parsePicNetConfig(String jsonStr) {
  final decoded = json.decode(jsonStr) as Map<String, dynamic>;
  return PicNetConfig.fromJson(decoded);
}
