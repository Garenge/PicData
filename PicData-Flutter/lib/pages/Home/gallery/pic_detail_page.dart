import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/pic_content.dart';
import '../../../models/pic_net_models.dart';
import '../../../services/net_client.dart';
import '../../../services/web_page_parser.dart';
import 'pic_content_grid.dart';
import '../../../debug/page_backdoor.dart';

/// 套图详情页。
///
/// 当前版本会根据 `PicContent.href` 请求详情页 HTML，
/// 并解析出当前页的图片列表和推荐套图列表，然后在控制台打印出来。
class PicDetailPage extends StatefulWidget {
  const PicDetailPage({super.key, required this.content, this.host});

  final PicContent content;
  final PicHost? host;

  @override
  State<PicDetailPage> createState() => _PicDetailPageState();
}

class _PicDetailPageState extends State<PicDetailPage> {
  bool _isLoading = false;
  Object? _error;
  List<String> _imageUrls = <String>[];
  List<PicContent> _suggestions = <PicContent>[];
  Map<String, String>? _imageHeaders;

  @override
  void initState() {
    super.initState();
    _imageHeaders = _buildImageHeaders();
    _loadDetail();
  }

  Map<String, String>? _buildImageHeaders() {
    final headers = <String, String>{};

    // 详情页图片请求的 Referer 更接近 OC 端逻辑：
    // 使用当前套图页的地址作为 Referer，而不是站点级的 HOST_URL。
    final detailHref = widget.content.href;
    if (detailHref.isNotEmpty) {
      headers['referer'] = detailHref;
    } else {
      final fallbackReferer = widget.host?.referer;
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

  Future<void> _loadDetail() async {
    final href = widget.content.href;
    if (href.isEmpty) {
      // ignore: avoid_print
      print('PicDetailPage: empty href for content="${widget.content.title}"');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final html = await NetClient.instance.getText(
        href,
        headers: _imageHeaders,
      );

      final parser = const WebPageParser();
      final images = parser.parseDetailImages(
        html: html,
        host: widget.host,
        detailUrl: href,
      );
      final suggestions = parser.parseDetailSuggestions(
        html: html,
        host: widget.host,
        detailUrl: href,
      );

      // ignore: avoid_print
      print('PicDetailPage: imageUrls for href="$href":');
      // ignore: avoid_print
      print(images);

      // ignore: avoid_print
      print('PicDetailPage: suggestions for href="$href":');
      // 只打印关键字段，避免日志过长。
      // ignore: avoid_print
      print(
        suggestions
            .map(
              (e) => {
                'title': e.title,
                'href': e.href,
                'thumbnail': e.thumbnail,
              },
            )
            .toList(),
      );

      if (!mounted) return;
      setState(() {
        _imageUrls = images;
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e, stack) {
      // ignore: avoid_print
      print('PicDetailPage _loadDetail ERROR for href=$href');
      // ignore: avoid_print
      print('  errorType=${e.runtimeType}');
      // ignore: avoid_print
      print('  error=$e');
      // ignore: avoid_print
      print('  stackTrace=$stack');

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hostTitle = widget.host?.title ?? widget.host?.mark ?? '-';
    final sourceType = widget.host?.sourceType?.toString() ?? '-';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: () => debugPrintPageBackdoorInfo(
              className: 'PicDetailPage',
              filePath: 'PicData-Flutter/lib/pages/Home/gallery/pic_detail_page.dart',
            ),
            child: Text(
              widget.content.title.isEmpty ? '套图详情' : widget.content.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        body: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: () => debugPrintPageBackdoorInfo(
              className: 'PicDetailPage',
              filePath: 'PicData-Flutter/lib/pages/Home/gallery/pic_detail_page.dart',
            ),
            child: Text(
              widget.content.title.isEmpty ? '套图详情' : widget.content.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '加载详情失败：$_error',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => debugPrintPageBackdoorInfo(
            className: 'PicDetailPage',
            filePath: 'PicData-Flutter/lib/pages/Home/gallery/pic_detail_page.dart',
          ),
          child: Text(
            widget.content.title.isEmpty ? '套图详情' : widget.content.title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前站点：$hostTitle (sourceType=$sourceType)',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    '详情地址（href）：\n${widget.content.href}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '推荐套图：${_suggestions.length} 个',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  if (_suggestions.isNotEmpty)
                    ExpansionTile(
                      title: Text('推荐套图（${_suggestions.length}）'),
                      childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      children: [
                        PicContentGrid(
                          contents: _suggestions,
                          headers: _imageHeaders,
                          itemWidth: 140,
                          padding: EdgeInsets.zero,
                          enableHover: false,
                          showDownloadButton: false,
                          onItemTap: (item) {
                            // ignore: avoid_print
                            print(
                              'Tap suggestion -> title="${item.title}", href="${item.href}"',
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '当前页图片：${_imageUrls.length} 张',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
            sliver: _imageUrls.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(child: Text('当前页暂无图片')),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final url = _imageUrls[index];
                      final total = _imageUrls.length;
                      return Padding(
                        key: ValueKey<String>(url),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              CachedNetworkImage(
                                imageUrl: url,
                                httpHeaders: _imageHeaders,
                                alignment: Alignment.topCenter,
                                fit: BoxFit.contain,
                                placeholder: (context, _) => Container(
                                  color: theme.colorScheme.surfaceVariant
                                      .withValues(alpha: 0.5),
                                  height: 160,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, _, __) => Container(
                                  color: theme.colorScheme.surfaceVariant
                                      .withValues(alpha: 0.5),
                                  height: 160,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    size: 32,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${index + 1}/$total',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: _imageUrls.length),
                  ),
          ),
        ],
      ),
    );
  }
}
