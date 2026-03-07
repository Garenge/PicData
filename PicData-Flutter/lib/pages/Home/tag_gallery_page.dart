import 'package:flutter/material.dart';

import '../../models/home_entry.dart';
import '../../models/pic_net_models.dart';
import '../../models/pic_content.dart';
import '../../services/net_client.dart';
import '../../services/web_page_parser.dart';

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

  /// 根据当前站点配置构造请求需要的 Header。
  ///
  /// - 如果配置了 `PicHost.referer`，则填充 `referer` 字段；
  /// - 统一追加一个桌面浏览器的 User-Agent，尽量模拟真实浏览器环境。
  Map<String, String>? _buildImageHeaders() {
    final headers = <String, String>{};

    final referer = widget.host?.referer;
    if (referer != null && referer.isNotEmpty) {
      headers['referer'] = referer;
    }

    headers['User-Agent'] =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_1) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/87.0.4280.66 Safari/537.36';

    if (headers.isEmpty) return null;
    return headers;
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
      appBar: AppBar(title: Text(widget.entry.title)),
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

          final contents = snapshot.data ?? <PicContent>[];
          if (contents.isEmpty) {
            return const Center(child: Text('暂无数据'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              const double itemWidth = 180;
              const double spacing = 12;
              final headers = _buildImageHeaders();

              // 根据屏幕宽度动态计算每行展示几个 cell
              final maxWidth = constraints.maxWidth;
              final int crossAxisCount = (maxWidth / (itemWidth + spacing))
                  .floor()
                  .clamp(1, 6);

              final gridWidth =
                  crossAxisCount * (itemWidth + spacing) - spacing;

              return Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  child: SizedBox(
                    width: gridWidth,
                    child: GridView.builder(
                      itemCount: contents.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                ),
              );
            },
          );
        },
      ),
    );
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
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _isDownloaded = widget.item.isDownloaded ?? false;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    final headers = widget.headers;

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
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
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
                'Tap PicContent -> service="${host?.title}", mark="${host?.mark}", sourceType=${host?.sourceType}',
              );
              // ignore: avoid_print
              print('  thumbnail="${item.thumbnail}"');
              // ignore: avoid_print
              print('  image headers=$headers');
            },
            hoverColor: Colors.black.withOpacity(0.02),
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _GalleryThumbnail(
                    imageUrl: item.thumbnail,
                    headers: headers,
                    title: item.title,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  if (!_isDownloaded)
                        IconButton(
                          tooltip: '下载',
                          iconSize: 20,
                          splashRadius: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.download_outlined),
                          onPressed: () {
                        // ignore: avoid_print
                        print('已将「${item.title}」加入下载列表');
                        if (!_isDownloaded) {
                          setState(() {
                            _isDownloaded = true;
                          });
                        }
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
  }
}

/// 统一的缩略图展示组件：优先加载网络缩略图，失败或无图时使用系统占位缩略图。
class _GalleryThumbnail extends StatelessWidget {
  const _GalleryThumbnail({
    required this.imageUrl,
    required this.headers,
    required this.title,
  });

  final String imageUrl;
  final Map<String, String>? headers;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 没有远程缩略图时，直接使用占位图。
    if (imageUrl.isEmpty) {
      return _buildPlaceholder(theme);
    }

    // 有远程缩略图时：先显示占位图，等网络图片加载成功后替换显示。
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPlaceholder(theme),
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            headers: headers,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // 加载完成，显示真实图片。
                return child;
              }
              // 加载中仍然只显示占位图（由下层容器提供）。
              return const SizedBox.shrink();
            },
            errorBuilder: (context, error, stackTrace) {
              // 远程图片加载失败时，保持下层占位图，不额外显示错误样式。
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    final bgColor = theme.colorScheme.surfaceVariant.withOpacity(0.6);
    final borderColor = theme.dividerColor.withOpacity(0.3);

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        color: bgColor,
        border: Border.all(color: borderColor, width: 0.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgColor, bgColor.withOpacity(0.4)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_outlined,
              size: 32,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 6),
            Text(
              '套图',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
