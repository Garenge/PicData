import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:pic_data/utils/gallery_grid_layout.dart';

/// 套图列表风格缩略图：网络图 + 占位；与 [TagGalleryPage] 网格 cell 上图区域一致。
class GalleryListThumbnail extends StatelessWidget {
  const GalleryListThumbnail({
    super.key,
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

    if (imageUrl.isEmpty) {
      return _buildPlaceholder(theme, context);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPlaceholder(theme, context),
          CachedNetworkImage(
            imageUrl: imageUrl,
            httpHeaders: headers,
            fit: BoxFit.cover,
            placeholder: (context, _) => const SizedBox.shrink(),
            errorWidget: (context, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, BuildContext context) {
    final compact = isCompactGalleryGrid(context);
    final bgColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.6,
    );
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
              size: compact ? 22 : 32,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              '套图',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: compact ? 0.8 : 1.2,
                fontSize: compact ? 10 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
