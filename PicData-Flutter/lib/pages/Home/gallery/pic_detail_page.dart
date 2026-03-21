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
  final ScrollController _scrollController = ScrollController();
  late String _currentHref;
  late List<String> _hrefHistory;

  bool _isLoading = false;
  Object? _error;
  List<String> _imageUrls = <String>[];
  List<PicContent> _suggestions = <PicContent>[];
  String? _nextHref;
  Map<String, String>? _imageHeaders;

  @override
  void initState() {
    super.initState();
    _currentHref = widget.content.href;
    _hrefHistory = <String>[_currentHref];
    _imageHeaders = _buildImageHeaders(_currentHref);
    _loadDetailForHref(_currentHref);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _canGoPrev => _hrefHistory.length > 1;

  String? get _prevHref => _canGoPrev ? _hrefHistory[_hrefHistory.length - 2] : null;

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    await _scrollController.animateTo(
      maxExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'pic-detail-to-top',
          onPressed: _scrollToTop,
          tooltip: '回到顶部',
          child: const Icon(Icons.vertical_align_top),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          heroTag: 'pic-detail-to-bottom',
          onPressed: _scrollToBottom,
          tooltip: '跳到底部',
          child: const Icon(Icons.vertical_align_bottom),
        ),
      ],
    );
  }

  Future<bool> _loadDetailForHref(String href) async {
    if (href.isEmpty) return false;

    setState(() {
      _isLoading = true;
      _error = null;
      _nextHref = null; // 避免上一页的 nextHref 误显示
      _imageHeaders = _buildImageHeaders(href);
    });

    try {
      final html = await NetClient.instance.getText(
        href,
        headers: _imageHeaders,
      );

      print(
        'PicDetailPage: load detail href="$href" '
        'hostTitle="${widget.host?.title}" hostMark="${widget.host?.mark}" '
        'sourceType=${widget.host?.sourceType} hostUrl="${widget.host?.hostUrl}"',
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

      final nextHref = parser.parseDetailNextPageUrl(
        html: html,
        host: widget.host,
        detailUrl: href,
      );

      print(
        'PicDetailPage: parsed href="$href" '
        'images=${images.length} suggestions=${suggestions.length} '
        'nextHref="${nextHref ?? ''}"',
      );

      // 只打印“样例”而不是整数组，避免日志失焦。
      final imageSample = images.take(3).join(' | ');
      final suggestionSample = suggestions
          .take(3)
          .map((e) => '${e.title} => ${e.href}')
          .join(' | ');
      // ignore: avoid_print
      print(
        'PicDetailPage: samples (first3) '
        'imageUrls="[$imageSample]" '
        'suggestions="[$suggestionSample]"',
      );

      if (!mounted) return false;
      setState(() {
        _currentHref = href;
        _imageUrls = images;
        _suggestions = suggestions;
        _nextHref = (nextHref != null && nextHref.isNotEmpty) ? nextHref : null;
        print(
          'PicDetailPage._loadDetailForHref.setState: '
          'committed nextHref="${_nextHref ?? ''}" '
          'hasNextHref=${_nextHref?.isNotEmpty ?? false}',
        );
        _isLoading = false;
      });
      print(
        'PicDetailPage._loadDetailForHref: after setState call '
        'mounted=$mounted nextHref="${_nextHref ?? ''}" isLoading=$_isLoading',
      );
      return true;
    } catch (e, stack) {
      // ignore: avoid_print
      print('PicDetailPage _loadDetailForHref ERROR for href=$href');
      // ignore: avoid_print
      print('  errorType=${e.runtimeType}');
      // ignore: avoid_print
      print('  error=$e');
      // ignore: avoid_print
      print('  stackTrace=$stack');

      if (!mounted) return false;
      setState(() {
        _isLoading = false;
        _error = e;
      });
      return false;
    }
  }

  Map<String, String>? _buildImageHeaders(String href) {
    final headers = <String, String>{};

    // 详情页图片请求的 Referer 更接近 OC 端逻辑：
    // 使用当前套图页的地址作为 Referer，而不是站点级的 HOST_URL。
    if (href.isNotEmpty) {
      headers['referer'] = href;
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

  AppBar _buildAppBar(String titleText) {
    final hasNextHref = _nextHref?.isNotEmpty ?? false;
    print(
      'PicDetailPage._buildAppBar: isLoading=$_isLoading '
      'hasNextHref=$hasNextHref nextHref="${_nextHref ?? ''}"',
    );
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: _canGoPrev ? 132 : 56,
      leading: Row(
        children: [
          const BackButton(),
          if (_canGoPrev)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final currentHref = _hrefHistory.last;
                          final prevHref = _prevHref;
                          if (prevHref == null || prevHref.isEmpty) return;

                          _hrefHistory.removeLast();
                          final success = await _loadDetailForHref(prevHref);
                          if (!success) {
                            // 回滚：尽量保留上一页按钮前的内容。
                            _hrefHistory.add(currentHref);
                            await _loadDetailForHref(currentHref);
                          }
                        },
                  child: const Text('上一页'),
                ),
              ),
            ),
        ],
      ),
      title: GestureDetector(
        onTap: () => debugPrintPageBackdoorInfo(
          className: 'PicDetailPage',
          filePath: 'PicData-Flutter/lib/pages/Home/gallery/pic_detail_page.dart',
        ),
        child: Text(
          titleText,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      actions: [
        if (hasNextHref)
          TextButton(
            onPressed: _isLoading
                ? null
                : () async {
                    final currentHref = _hrefHistory.last;
                    final nextHref = _nextHref;
                    if (nextHref == null || nextHref.isEmpty) return;

                    _hrefHistory.add(nextHref);
                    final success = await _loadDetailForHref(nextHref);
                    if (!success) {
                      // 回滚：尽量保留点击 next 前的内容。
                      _hrefHistory.removeLast();
                      await _loadDetailForHref(currentHref);
                    }
                  },
            child: const Text('下一页'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hostTitle = widget.host?.title ?? widget.host?.mark ?? '-';
    final sourceType = widget.host?.sourceType?.toString() ?? '-';
    final titleText = widget.content.title.isEmpty ? '套图详情' : widget.content.title;
    final hasNextHref = _nextHref?.isNotEmpty ?? false;
    print(
      'PicDetailPage.build: isLoading=$_isLoading error=${_error != null} '
      'hasNextHref=$hasNextHref nextHref="${_nextHref ?? ''}" '
      'images=${_imageUrls.length} suggestions=${_suggestions.length}',
    );

    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(titleText),
        floatingActionButton: _buildFloatingActions(),
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
        appBar: _buildAppBar(titleText),
        floatingActionButton: _buildFloatingActions(),
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
      appBar: _buildAppBar(titleText),
      floatingActionButton: _buildFloatingActions(),
      body: CustomScrollView(
        controller: _scrollController,
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
                    '详情地址（href）：\n$_currentHref',
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
