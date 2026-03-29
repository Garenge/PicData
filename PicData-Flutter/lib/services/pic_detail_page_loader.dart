import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/services/net_client.dart';
import 'package:pic_data/services/web_page_parser.dart';

/// 单套详情页一次请求 + 解析的结果（与 UI 状态字段对齐，便于复用）。
class PicDetailLoadedPage {
  const PicDetailLoadedPage({
    required this.href,
    required this.imageUrls,
    this.nextHref,
    this.suggestions = const [],
  });

  final String href;
  final List<String> imageUrls;
  final String? nextHref;
  final List<PicContent> suggestions;
}

/// 详情页「拉取 HTML + 解析图片 / 下一页 / 推荐」的共享逻辑。
///
/// [PicDetailPage] 与 [PicSetDownloadManager] 共用此类，避免两套解析分叉。
class PicDetailPageLoader {
  PicDetailPageLoader({
    WebPageParser? parser,
    NetClient? netClient,
  })  : _parser = parser ?? const WebPageParser(),
        _net = netClient ?? NetClient.instance;

  final WebPageParser _parser;
  final NetClient _net;

  /// 与详情页图片请求一致的 Referer / User-Agent。
  static Map<String, String>? buildDetailRequestHeaders({
    required String detailUrl,
    PicHost? host,
  }) {
    final headers = <String, String>{};

    if (detailUrl.isNotEmpty) {
      headers['referer'] = detailUrl;
    } else {
      final fallbackReferer = host?.referer;
      if (fallbackReferer != null && fallbackReferer.isNotEmpty) {
        headers['referer'] = fallbackReferer;
      }
    }

    headers['User-Agent'] =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_1) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/87.0.4280.66 Safari/537.36';

    if (headers.isEmpty) return null;
    return headers;
  }

  /// 请求 [href] 对应详情 HTML，并解析当前页图片、下一页链接、推荐套图。
  ///
  /// [compactDiagnostics]：批量爬取时用紧凑 HTTP 日志、关闭分页解析的啰嗦调试输出。
  Future<PicDetailLoadedPage> loadPage({
    required String href,
    required PicHost? host,
    bool compactDiagnostics = false,
  }) async {
    if (href.isEmpty) {
      throw ArgumentError.value(href, 'href', 'must not be empty');
    }

    final requestHeaders = buildDetailRequestHeaders(
      detailUrl: href,
      host: host,
    );

    final logMode = compactDiagnostics
        ? NetTextRequestLogMode.compact
        : NetTextRequestLogMode.full;

    final html = await _net.getText(
      href,
      headers: requestHeaders,
      logMode: logMode,
    );

    final images = _parser.parseDetailImages(
      html: html,
      host: host,
      detailUrl: href,
    );

    final suggestions = _parser.parseDetailSuggestions(
      html: html,
      host: host,
      detailUrl: href,
    );

    final nextRaw = _parser.parseDetailNextPageUrl(
      html: html,
      host: host,
      detailUrl: href,
      emitPaginationDebugLog: !compactDiagnostics,
    );

    final nextHref =
        (nextRaw != null && nextRaw.isNotEmpty) ? nextRaw : null;

    return PicDetailLoadedPage(
      href: href,
      imageUrls: images,
      nextHref: nextHref,
      suggestions: suggestions,
    );
  }
}
