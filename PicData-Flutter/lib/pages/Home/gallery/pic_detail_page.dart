import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/services/pic_detail_page_loader.dart';
import 'package:pic_data/services/pic_download_module.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';
import 'package:pic_data/utils/pic_content_download_flags.dart';
import 'pic_content_grid.dart';
import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/pages/files/open_download_record_local_folder.dart';

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
  final PicDetailPageLoader _detailLoader = PicDetailPageLoader();
  late String _currentHref;
  late List<String> _hrefHistory;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;
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
    _imageHeaders = PicDetailPageLoader.buildDetailRequestHeaders(
      detailUrl: _currentHref,
      host: widget.host,
    );
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
          child: const Icon(Icons.arrow_upward),
        ),
        const SizedBox(height: 12),
        FloatingActionButton.small(
          heroTag: 'pic-detail-to-bottom',
          onPressed: _scrollToBottom,
          tooltip: '跳到底部',
          child: const Icon(Icons.arrow_downward),
        ),
      ],
    );
  }

  void _enqueueDownloadSet(PicContent content) {
    PicDownloadModule.instance.enqueueDownloadSet(
      content: content,
      host: widget.host,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已加入下载队列，后台解析并保存到下载目录')),
    );
  }

  void _onTapDownloadSet() => _enqueueDownloadSet(widget.content);

  Future<void> _reloadCurrentPage() async {
    final href = _currentHref;
    if (href.isEmpty) return;
    await _loadDetailForHref(href);
  }

  Future<bool> _loadDetailForHref(String href) async {
    if (href.isEmpty) return false;
    final requestHeaders = PicDetailPageLoader.buildDetailRequestHeaders(
      detailUrl: href,
      host: widget.host,
    );

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print(
        'PicDetailPage: load detail href="$href" '
        'hostTitle="${widget.host?.title}" hostMark="${widget.host?.mark}" '
        'sourceType=${widget.host?.sourceType} hostUrl="${widget.host?.hostUrl}"',
      );

      final loaded = await _detailLoader.loadPage(
        href: href,
        host: widget.host,
      );

      final images = loaded.imageUrls;
      final suggestions = loaded.suggestions;
      final nextHref = loaded.nextHref;

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
        _imageHeaders = requestHeaders;
        _nextHref = (nextHref != null && nextHref.isNotEmpty) ? nextHref : null;
        _hasLoadedOnce = true;
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
        IconButton(
          tooltip: '重新加载本页',
          onPressed: _isLoading ? null : _reloadCurrentPage,
          icon: const Icon(Icons.refresh),
        ),
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
        ListenableBuilder(
          listenable: PicSetDownloadRecordStore.instance,
          builder: (BuildContext context, Widget? _) {
            final String entryHref = widget.content.href;
            final bool inDownloadList = entryHref.isNotEmpty &&
                PicSetDownloadRecordStore.instance.trackedContentHrefSet
                    .contains(entryHref);
            if (inDownloadList) {
              final PicSetDownloadRecord? downloadRecord =
                  PicSetDownloadRecordStore.instance
                      .tryGetRecordByContentHref(entryHref);
              if (downloadRecord == null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: '打开本套图下载文件夹',
                icon: const Icon(Icons.folder_open_outlined),
                onPressed: () async {
                  await pushFileBrowserForDownloadRecord(
                    context,
                    downloadRecord,
                  );
                },
              );
            }
            return IconButton(
              tooltip: '下载整套到本机（队列）',
              onPressed: _isLoading ? null : _onTapDownloadSet,
              icon: const Icon(Icons.download_outlined),
            );
          },
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

    final shouldShowFullLoading = _isLoading && !_hasLoadedOnce;
    final shouldShowFullError = _error != null && !_hasLoadedOnce;

    if (shouldShowFullLoading) {
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

    if (shouldShowFullError) {
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

    return Stack(
      children: [
        Scaffold(
          appBar: _buildAppBar(titleText),
          floatingActionButton: _buildFloatingActions(),
          body: Stack(
            children: [
              CustomScrollView(
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
                      if (_error != null)
                        Text(
                          '最新请求失败，保留当前内容：$_error',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      if (_error != null) const SizedBox(height: 8),
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
                            ListenableBuilder(
                              listenable: PicSetDownloadRecordStore.instance,
                              builder: (BuildContext context, Widget? _) {
                                final List<PicContent> flagged =
                                    applyCompletedDownloadFlagsToContents(
                                  _suggestions,
                                  PicSetDownloadRecordStore
                                      .instance.completedContentHrefSet,
                                );
                                return PicContentGrid(
                                  contents: flagged,
                                  headers: _imageHeaders,
                                  itemWidth: 140,
                                  padding: EdgeInsets.zero,
                                  enableHover: false,
                                  onDownloadTap: _enqueueDownloadSet,
                                  onItemTap: (item) {
                                    // ignore: avoid_print
                                    print(
                                      'Tap suggestion -> title="${item.title}", href="${item.href}"',
                                    );
                                    if (item.href.isEmpty) return;
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PicDetailPage(
                                          content: item,
                                          host: widget.host,
                                        ),
                                      ),
                                    );
                                  },
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
              if (_isLoading)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
        ),
        if (_isLoading && _hasLoadedOnce)
          Positioned.fill(
            child: Stack(
              children: const [
                ModalBarrier(
                  dismissible: false,
                  color: Color(0x33000000),
                ),
                Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
