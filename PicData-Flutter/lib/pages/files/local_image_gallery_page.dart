import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:pic_data/debug/page_backdoor.dart';

const String _logPath = 'PicData-Flutter/lib/pages/files/local_image_gallery_page.dart';

/// 同目录下本地图片的缩放 + 左右滑动画廊（路径列表由 [FileBrowserPage] 按自然序收集）。
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
    // mac 常用：Cmd+← / Cmd+→ 跳到首/尾（通过按下 Command 键推断）
    final bool isCommandPressed =
        HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed;
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
    // mac 上 Esc / ↑ / ↓ / Space 都可快速退出预览
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

  @override
  Widget build(BuildContext context) {
    final int total = widget.imagePaths.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        title: GestureDetector(
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
        ),
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
                        // ignore: avoid_print
                        print(
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
            if (_metaText != null)
              Material(
                color: Colors.black.withValues(alpha: 0.85),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      ),
    );
  }
}
