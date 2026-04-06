import 'package:pic_data/models/pic_net_models.dart';

/// 与列表页 `_GalleryThumbnail` / [CachedNetworkImage] 使用的请求头一致（套图网格、下载记录缩略图等复用）。
///
/// 与历史实现一致：至少包含 User-Agent；若 [host] 配置了 referer 则一并带上。
Map<String, String> buildGalleryListImageHeaders(PicHost? host) {
  final headers = <String, String>{};
  final referer = host?.referer;
  if (referer != null && referer.isNotEmpty) {
    headers['referer'] = referer;
  }
  headers['User-Agent'] = _kGalleryListImageUserAgent;
  return headers;
}

const String _kGalleryListImageUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_1) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/87.0.4280.66 Safari/537.36';
