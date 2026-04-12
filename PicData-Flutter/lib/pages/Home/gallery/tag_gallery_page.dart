import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pic_data/models/home_entry.dart';
import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/services/net_client.dart';
import 'package:pic_data/services/pic_download_module.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';
import 'package:pic_data/services/web_page_parser.dart';
import 'package:pic_data/utils/pic_content_download_flags.dart';
import 'package:pic_data/utils/gallery_grid_layout.dart';
import 'package:pic_data/utils/gallery_list_image_headers.dart';
import 'package:pic_data/widgets/gallery_list_thumbnail.dart';
import 'package:pic_data/debug/page_backdoor.dart';
import 'pic_content_grid.dart';
import 'pic_detail_page.dart';

OverlayEntry? _activeHudEntry;
Timer? _activeHudTimer;

/// 居中 HUD 提示：短时显示，不占底部按钮区域。
void _showCenterHud(BuildContext context, String message) {
  _activeHudTimer?.cancel();
  _activeHudTimer = null;
  _activeHudEntry?.remove();
  _activeHudEntry = null;

  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  final double maxWidth = MediaQuery.sizeOf(context).width * 0.5;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) {
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  _activeHudEntry = entry;
  overlay.insert(entry);
  _activeHudTimer = Timer(const Duration(milliseconds: 1600), () {
    _activeHudTimer = null;
    _activeHudEntry?.remove();
    _activeHudEntry = null;
  });
}

/// 某个标签 / 入口对应的图集列表页面。
///
/// 当前实现：进入页面后先请求入口 URL，对网页内容做一次简单解析，
/// 把结果文本打印在页面上，后续再替换为真实图集展示逻辑。
class TagGalleryPage extends StatefulWidget {
  const TagGalleryPage({super.key, required this.entry, this.host});

  /// 当前选中的首页入口（包含标题和 URL）
  final HomeEntry entry;

  /// 进入本页时选中的服务配置（用于解析 HTML，决定 sourceType 等）
  final PicHost? host;

  @override
  State<TagGalleryPage> createState() => _TagGalleryPageState();
}

class _TagGalleryPageState extends State<TagGalleryPage> {
  Future<List<PicContent>> _contentsFuture = Future<List<PicContent>>.value(
    <PicContent>[],
  );
  final List<PicContent> _extraContents = <PicContent>[];
  String? _nextPageUrl;
  bool _isLoadingMore = false;
  Object? _loadMoreError;

  Map<String, String> _buildImageHeaders() {
    return buildGalleryListImageHeaders(widget.host);
  }

  @override
  void initState() {
    super.initState();
    _contentsFuture = _loadPageContents();
  }

  Future<List<PicContent>> _loadPageContents() async {
    final url = widget.entry.url;
    if (url.isEmpty) {
      // 返回一个仅包含提示信息的“占位内容”，方便统一用列表展示
      return <PicContent>[
        PicContent(title: '当前入口没有配置 URL', href: '', thumbnail: ''),
      ];
    }

    // 1. 通过网络工具类请求网页内容（附带与图片相同的 Header）
    final html = await NetClient.instance.getText(
      url,
      headers: _buildImageHeaders(),
    );

    // 2. 控制台打印一份原始内容长度，方便调试
    // ignore: avoid_print
    print('Loaded html from $url, length=${html.length}');

    // 3. 根据当前站点（host.sourceType）解析套图列表
    final parser = const WebPageParser();
    final contents = parser.parseContentList(
      html: html,
      host: widget.host,
      entryUrl: url,
    );

    // 4. 解析下一页链接
    final nextPage = parser.parseNextPageUrl(
      html: html,
      host: widget.host,
      entryUrl: url,
    );
    if (mounted) {
      setState(() {
        _nextPageUrl = (nextPage != null && nextPage.isNotEmpty)
            ? nextPage
            : null;
      });
    }

    if (contents.isEmpty) {
      // 若解析失败，则返回一个占位项提示。
      return <PicContent>[
        PicContent(
          title: '未能从页面解析出套图列表（原始长度：${html.length}）',
          href: url,
          thumbnail: '',
        ),
      ];
    }

    return contents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => debugPrintPageBackdoorInfo(
            className: 'TagGalleryPage',
            filePath: 'PicData-Flutter/lib/pages/Home/gallery/tag_gallery_page.dart',
          ),
          child: Text(widget.entry.title),
        ),
      ),
      body: FutureBuilder<List<PicContent>>(
        future: _contentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final stack = snapshot.stackTrace;
            // ignore: avoid_print
            print(
              'TagGalleryPage _loadPageContent ERROR for url=${widget.entry.url}',
            );
            // ignore: avoid_print
            print('  errorType=${error.runtimeType}');
            // ignore: avoid_print
            print('  error=$error');
            if (stack != null) {
              // ignore: avoid_print
              print('  stackTrace=$stack');
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '加载失败：${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          return ListenableBuilder(
            listenable: PicSetDownloadRecordStore.instance,
            builder: (BuildContext context, Widget? _) {
              final Set<String> completed =
                  PicSetDownloadRecordStore.instance.completedContentHrefSet;
              final List<PicContent> initialContents =
                  applyCompletedDownloadFlagsToContents(
                snapshot.data ?? <PicContent>[],
                completed,
              );
              final List<PicContent> extraFlagged =
                  applyCompletedDownloadFlagsToContents(
                _extraContents,
                completed,
              );
              final contents = <PicContent>[
                ...initialContents,
                ...extraFlagged,
              ];
              if (contents.isEmpty) {
                return const Center(child: Text('暂无数据'));
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final double spacing = galleryGridSpacing(context);
                  const double desktopItemWidth = 180;
                  final headers = _buildImageHeaders();

                  // 根据屏幕宽度动态计算每行展示几个 cell（窄屏收紧目标宽度以保证约三列）
                  final horizontalInset = galleryPageHorizontalInset(context);
                  final maxWidth =
                      constraints.maxWidth - 2 * horizontalInset;
                  final double itemWidth = PicContentGrid.resolveItemWidth(
                    context,
                    maxWidth,
                    desktopItemWidth,
                    spacing: spacing,
                  );
                  final int crossAxisCount = (maxWidth / (itemWidth + spacing))
                      .floor()
                      .clamp(1, 6);

                  final gridWidth =
                      crossAxisCount * (itemWidth + spacing) - spacing;
                  final double sidePadding =
                      ((maxWidth - gridWidth) / 2).clamp(0, double.infinity);

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: horizontalInset,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: GridView.builder(
                            padding:
                                EdgeInsets.symmetric(horizontal: sidePadding),
                            itemCount: contents.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: spacing,
                              crossAxisSpacing: spacing,
                              // 控制高度（缩略图 + 标题区域），大约 4:5
                              childAspectRatio: 3 / 4,
                            ),
                            itemBuilder: (context, index) {
                              final item = contents[index];
                              return _TagGalleryItem(
                                key: ValueKey(
                                  item.href.isNotEmpty
                                      ? item.href
                                      : '${item.title}#$index',
                                ),
                                item: item,
                                headers: headers,
                                host: widget.host,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (_nextPageUrl != null)
                          Align(
                            alignment: Alignment.center,
                            child: TextButton.icon(
                              onPressed: _loadNextPage,
                              icon: const Icon(Icons.expand_more),
                              label: const Text('加载更多'),
                            ),
                          ),
                        if (_loadMoreError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '加载更多失败：$_loadMoreError',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadNextPage() async {
    final nextUrl = _nextPageUrl;
    if (nextUrl == null || nextUrl.isEmpty || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final html = await NetClient.instance.getText(
        nextUrl,
        headers: _buildImageHeaders(),
      );

      // ignore: avoid_print
      print('Loaded next page html from $nextUrl, length=${html.length}');

      final parser = const WebPageParser();
      final newContents = parser.parseContentList(
        html: html,
        host: widget.host,
        entryUrl: nextUrl,
      );
      final nextPage = parser.parseNextPageUrl(
        html: html,
        host: widget.host,
        entryUrl: nextUrl,
      );

      if (!mounted) return;
      setState(() {
        _extraContents.addAll(newContents);
        _nextPageUrl = (nextPage != null && nextPage.isNotEmpty)
            ? nextPage
            : null;
        _isLoadingMore = false;
      });
    } catch (e, stack) {
      // ignore: avoid_print
      print('TagGalleryPage _loadNextPage ERROR for url=$nextUrl');
      // ignore: avoid_print
      print('  errorType=${e.runtimeType}');
      // ignore: avoid_print
      print('  error=$e');
      // ignore: avoid_print
      print('  stackTrace=$stack');

      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = e;
      });
    }
  }
}

class _TagGalleryItem extends StatefulWidget {
  const _TagGalleryItem({
    super.key,
    required this.item,
    required this.headers,
    required this.host,
  });

  final PicContent item;
  final Map<String, String>? headers;
  final PicHost? host;

  @override
  State<_TagGalleryItem> createState() => _TagGalleryItemState();
}

class _TagGalleryItemState extends State<_TagGalleryItem>
    with AutomaticKeepAliveClientMixin<_TagGalleryItem> {
  bool _isHovered = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    final headers = widget.headers;

    return ListenableBuilder(
      listenable: PicSetDownloadRecordStore.instance,
      builder: (BuildContext context, Widget? _) {
        final bool inDownloadList = item.href.isNotEmpty &&
            PicSetDownloadRecordStore.instance.trackedContentHrefSet
                .contains(item.href);

        return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: _isHovered
            ? (Matrix4.identity()..scaleByDouble(1.02, 1.02, 1.02, 1))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Card(
          elevation: _isHovered ? 8 : 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              final host = widget.host;
              // ignore: avoid_print
              print(
                'Tap PicContent -> service="${host?.title}", '
                'mark="${host?.mark}", sourceType=${host?.sourceType}',
              );
              // ignore: avoid_print
              print('  PicContent.title   = "${item.title}"');
              // ignore: avoid_print
              print('  PicContent.href    = "${item.href}"');
              // ignore: avoid_print
              print('  PicContent.thumbnail = "${item.thumbnail}"');
              // ignore: avoid_print
              print('  image headers=$headers');

              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PicDetailPage(content: item, host: host),
                ),
              );
            },
            hoverColor: Colors.black.withValues(alpha: 0.02),
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GalleryListThumbnail(
                    imageUrl: item.thumbnail,
                    headers: headers,
                    title: item.title,
                  ),
                ),
                Padding(
                  padding: galleryGridCellTitleInsets(context),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: galleryGridTitleFontSize(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!inDownloadList)
                        IconButton(
                          tooltip: '下载',
                          iconSize: galleryGridDownloadIconSize(context),
                          splashRadius:
                              isCompactGalleryGrid(context) ? 20 : 31,
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () {
                            PicDownloadModule.instance.enqueueDownloadSet(
                              content: item,
                              host: widget.host,
                            );
                            _showCenterHud(
                              context,
                              '已加入下载队列，后台解析并保存到下载目录',
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}
