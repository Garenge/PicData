import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:swipe_image_gallery/swipe_image_gallery.dart';

import 'package:pic_data/debug/page_backdoor.dart';

const String _logPath = 'PicData-Flutter/lib/pages/files/local_image_gallery_page.dart';

/// 手机端使用 [SwipeImageGallery]（[InteractiveViewer] + **竖直拖动关闭**）；桌面端仍用 [LocalImageGalleryPage] + [photo_view]。
bool get localImageGalleryUseSwipeDialog =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// 本地文件全屏预览：左右滑切图、双指缩放、双击缩放、**下滑拖动超过阈值即关闭**（与 [PageView] 横向滚动不冲突）。
Future<void> showLocalSwipeImageGallery(
  BuildContext context, {
  required List<String> imagePaths,
  required int initialIndex,
}) async {
  if (imagePaths.isEmpty) {
    return;
  }
  final int n = imagePaths.length;
  final int safe = initialIndex.clamp(0, n - 1);
  final StreamController<Widget> overlayController =
      StreamController<Widget>.broadcast();

  try {
    await SwipeImageGallery<void>(
      context: context,
      itemCount: n,
      initialIndex: safe,
      dismissDragDistance: 100,
      hideOverlayOnTap: false,
      itemBuilder: (BuildContext ctx, int index) {
        final String path = imagePaths[index];
        return Image.file(
          File(path),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (BuildContext context, Object error, StackTrace? st) {
            debugPrint(
              '$_logPath#SwipeGallery Image.file error path=$path error=$error',
            );
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '无法加载图片',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        );
      },
      overlayController: overlayController,
      initialOverlay: _SwipeGalleryOverlay(
        imagePaths: imagePaths,
        index: safe,
      ),
      onSwipe: (int i) {
        overlayController.add(
          _SwipeGalleryOverlay(imagePaths: imagePaths, index: i),
        );
      },
    ).show();
  } finally {
    await overlayController.close();
  }
}

class _SwipeGalleryOverlay extends StatefulWidget {
  const _SwipeGalleryOverlay({
    required this.imagePaths,
    required this.index,
  });

  final List<String> imagePaths;
  final int index;

  @override
  State<_SwipeGalleryOverlay> createState() => _SwipeGalleryOverlayState();
}

class _SwipeGalleryOverlayState extends State<_SwipeGalleryOverlay> {
  String? _metaText;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void didUpdateWidget(covariant _SwipeGalleryOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index ||
        oldWidget.imagePaths.length != widget.imagePaths.length) {
      _loadMeta();
    }
  }

  Future<void> _loadMeta() async {
    try {
      final FileStat stat = await File(widget.imagePaths[widget.index]).stat();
      if (!mounted) return;
      final String sizeText = _formatBytes(stat.size);
      final DateTime modified = stat.modified.toLocal();
      final String ts =
          '${modified.year.toString().padLeft(4, '0')}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')} '
          '${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';
      setState(() {
        _metaText = '$sizeText · $ts';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _metaText = null);
      }
    }
  }

  String _formatBytes(int bytes) {
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.imagePaths.length;
    final String name = p.basename(widget.imagePaths[widget.index]);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: Colors.black.withValues(alpha: 0.55),
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).maybePop();
                    },
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => debugPrintPageBackdoorInfo(
                        className: 'LocalImageGalleryPage',
                        filePath: _logPath,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${widget.index + 1} / $total',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_metaText != null)
            Material(
              color: Colors.black.withValues(alpha: 0.85),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _metaText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 同目录下本地图片的缩放 + 左右滑动画廊（路径列表由 [FileBrowserPage] 按自然序收集）。
///
/// 当前仅在 **桌面端** 使用；手机端请调用 [showLocalSwipeImageGallery]。
class LocalImageGalleryPage extends StatefulWidget {
  const LocalImageGalleryPage({
    super.key,
    required this.imagePaths,
    required this.initialIndex,
  });

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<LocalImageGalleryPage> createState() => _LocalImageGalleryPageState();
}

class _LocalImageGalleryPageState extends State<LocalImageGalleryPage> {
  late final PageController _pageController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();
  String? _metaText;
  double? _baseScale;
  double? _currentScale;
  double _dragDeltaX = 0;

  @override
  void initState() {
    super.initState();
    assert(widget.imagePaths.isNotEmpty);
    final int n = widget.imagePaths.length;
    final int safe = widget.initialIndex.clamp(0, n - 1);
    _currentIndex = safe;
    _pageController = PageController(initialPage: safe);
    _updateMetaForIndex(safe);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _updateMetaForIndex(int index) async {
    try {
      final String path = widget.imagePaths[index];
      final File file = File(path);
      final FileStat stat = await file.stat();
      if (!mounted) return;
      final String sizeText = _formatBytes(stat.size);
      final DateTime modified = stat.modified.toLocal();
      final String ts =
          '${modified.year.toString().padLeft(4, '0')}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')} '
          '${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';
      setState(() {
        _metaText = '$sizeText · $ts';
      });
    } catch (_) {
      // 静默失败，不影响主流程
    }
  }

  String _formatBytes(int bytes) {
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;
    if (bytes < kb) return '$bytes B';
    if (bytes < mb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    if (bytes < gb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / gb).toStringAsFixed(1)} GB';
  }

  Future<void> _goToPrev() async {
    if (_currentIndex <= 0) {
      return;
    }
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNext() async {
    if (_currentIndex >= widget.imagePaths.length - 1) {
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final bool isCommandPressed =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && isCommandPressed) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight && isCommandPressed) {
      _pageController.animateToPage(
        widget.imagePaths.length - 1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _goToPrev();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _goToNext();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.space) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _isAtBaseScaleOrUnknown {
    if (_currentScale == null || _baseScale == null) {
      return true;
    }
    return _currentScale! <= _baseScale! * 1.02;
  }

  String _currentBaseName() {
    return p.basename(widget.imagePaths[_currentIndex]);
  }

  Widget _buildTitleColumn() {
    final int total = widget.imagePaths.length;
    return GestureDetector(
      onTap: () => debugPrintPageBackdoorInfo(
        className: 'LocalImageGalleryPage',
        filePath: _logPath,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _currentBaseName(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${_currentIndex + 1} / $total',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaFooter() {
    if (_metaText == null) {
      return const SizedBox.shrink();
    }
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          _metaText!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.imagePaths.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        title: _buildTitleColumn(),
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (FocusNode _, KeyEvent event) => _handleKeyEvent(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (DragStartDetails details) {
                  if (!_isAtBaseScaleOrUnknown) {
                    _dragDeltaX = 0;
                    return;
                  }
                  _dragDeltaX = 0;
                },
                onHorizontalDragUpdate: (DragUpdateDetails details) {
                  if (!_isAtBaseScaleOrUnknown) {
                    return;
                  }
                  _dragDeltaX += details.delta.dx;
                },
                onHorizontalDragEnd: (DragEndDetails details) {
                  if (!_isAtBaseScaleOrUnknown) {
                    _dragDeltaX = 0;
                    return;
                  }
                  const double threshold = 80;
                  if (_dragDeltaX > threshold) {
                    _goToPrev();
                  } else if (_dragDeltaX < -threshold) {
                    _goToNext();
                  }
                  _dragDeltaX = 0;
                },
                child: PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  pageController: _pageController,
                  itemCount: total,
                  onPageChanged: (int index) {
                    setState(() => _currentIndex = index);
                    _updateMetaForIndex(index);
                  },
                  builder: (BuildContext context, int index) {
                    final String path = widget.imagePaths[index];
                    return PhotoViewGalleryPageOptions(
                      imageProvider: FileImage(File(path)),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2.5,
                      initialScale: PhotoViewComputedScale.contained,
                      onTapUp: (
                        BuildContext context,
                        TapUpDetails details,
                        PhotoViewControllerValue value,
                      ) {
                        Navigator.of(context).maybePop();
                      },
                      onScaleEnd: (
                        BuildContext context,
                        ScaleEndDetails details,
                        PhotoViewControllerValue value,
                      ) {
                        final double scale = value.scale ?? 1.0;
                        setState(() {
                          _currentScale = scale;
                          _baseScale ??= scale;
                        });
                      },
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        debugPrint(
                          '$_logPath#PhotoView: load failed path=$path error=$error',
                        );
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '无法加载图片\n$error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loadingBuilder: (BuildContext context, ImageChunkEvent? event) {
                    if (event == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final int? totalBytes = event.expectedTotalBytes;
                    final double? value = totalBytes != null && totalBytes > 0
                        ? event.cumulativeBytesLoaded / totalBytes
                        : null;
                    return Center(child: CircularProgressIndicator(value: value));
                  },
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                ),
              ),
            ),
            _buildMetaFooter(),
          ],
        ),
      ),
    );
  }
}
