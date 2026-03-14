import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/pic_content.dart';

/// 通用的套图网格组件。
///
/// - 列表页和详情页的推荐区都可以复用这一套 UI；
/// - 通过 [itemWidth] 控制单个单元格的「目标宽度」，内部会自适应行数；
/// - 通过 [enableHover] / [showDownloadButton] 等参数控制交互差异。
class PicContentGrid extends StatelessWidget {
  const PicContentGrid({
    super.key,
    required this.contents,
    required this.headers,
    this.itemWidth = 180,
    this.padding = EdgeInsets.zero,
    this.enableHover = true,
    this.showDownloadButton = true,
    this.onItemTap,
    this.onDownloadTap,
  });

  final List<PicContent> contents;
  final Map<String, String>? headers;

  /// 期望的单个 cell 宽度，组件会根据可用宽度和间距动态计算每行个数。
  final double itemWidth;

  /// GridView 外侧的整体 padding。
  final EdgeInsetsGeometry padding;

  /// 是否启用 hover 放大和阴影效果（在桌面端列表页启用，在推荐区可以关闭）。
  final bool enableHover;

  /// 是否显示「下载」按钮。
  final bool showDownloadButton;

  /// 点击单个套图时的回调，由上层决定跳转逻辑。
  final void Function(PicContent item)? onItemTap;

  /// 点击下载按钮时的回调，由上层决定具体下载实现。
  final void Function(PicContent item)? onDownloadTap;

  @override
  Widget build(BuildContext context) {
    if (contents.isEmpty) {
      return const SizedBox.shrink();
    }

    const double spacing = 12;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final int crossAxisCount =
            (maxWidth / (itemWidth + spacing)).floor().clamp(1, 6);

        final gridWidth = crossAxisCount * (itemWidth + spacing) - spacing;
        final double sidePadding =
            ((maxWidth - gridWidth) / 2).clamp(0, double.infinity);

        return Padding(
          padding: padding,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: sidePadding),
            itemCount: contents.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 3 / 4,
            ),
            itemBuilder: (context, index) {
              final item = contents[index];
              return _PicContentGridItem(
                key: ValueKey(
                  item.href.isNotEmpty ? item.href : '${item.title}#$index',
                ),
                item: item,
                headers: headers,
                enableHover: enableHover,
                showDownloadButton: showDownloadButton,
                onTap: onItemTap,
                onDownloadTap: onDownloadTap,
              );
            },
          ),
        );
      },
    );
  }
}

class _PicContentGridItem extends StatefulWidget {
  const _PicContentGridItem({
    super.key,
    required this.item,
    required this.headers,
    required this.enableHover,
    required this.showDownloadButton,
    this.onTap,
    this.onDownloadTap,
  });

  final PicContent item;
  final Map<String, String>? headers;
  final bool enableHover;
  final bool showDownloadButton;
  final void Function(PicContent item)? onTap;
  final void Function(PicContent item)? onDownloadTap;

  @override
  State<_PicContentGridItem> createState() => _PicContentGridItemState();
}

class _PicContentGridItemState extends State<_PicContentGridItem>
    with AutomaticKeepAliveClientMixin<_PicContentGridItem> {
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

    final bool enableHover = widget.enableHover;
    final bool showDownloadButton = widget.showDownloadButton;

    final card = Card(
      elevation: enableHover && _isHovered ? 8 : 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => widget.onTap?.call(item),
        hoverColor: Colors.black.withValues(alpha: 0.02),
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
                  if (showDownloadButton && !_isDownloaded)
                    IconButton(
                      tooltip: '下载',
                      iconSize: 20,
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () {
                        widget.onDownloadTap?.call(item);
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
    );

    if (!enableHover) {
      return card;
    }

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
        transform:
            _isHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
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
        child: card,
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
          CachedNetworkImage(
            imageUrl: imageUrl,
            httpHeaders: headers,
            fit: BoxFit.cover,
            placeholder: (context, _) => const SizedBox.shrink(),
            errorWidget: (context, _, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    final bgColor = theme.colorScheme.surfaceVariant.withValues(alpha: 0.6);
    final borderColor = theme.dividerColor.withValues(alpha: 0.3);

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        color: bgColor,
        border: Border.all(color: borderColor, width: 0.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgColor, bgColor.withValues(alpha: 0.4)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_outlined,
              size: 32,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 6),
            Text(
              '套图',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

