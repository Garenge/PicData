import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/pages/Home/gallery/pic_detail_page.dart';
import 'package:pic_data/pages/files/file_browser_entry_kind.dart';
import 'package:pic_data/pages/files/local_image_gallery_page.dart';
import 'package:pic_data/pages/files/text_file_preview_page.dart';
import 'package:pic_data/pages/files/files_tab_refresh_scope.dart';
import 'package:pic_data/services/file_export_share_service.dart';
import 'package:pic_data/services/open_local_folder.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';
import 'package:pic_data/utils/filename_natural_compare.dart';
import 'package:pic_data/utils/gallery_grid_layout.dart';

class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({
    super.key,
    required this.directoryPath,
    required this.pageTitle,
  });

  final String directoryPath;
  final String pageTitle;

  @override
  State<FileBrowserPage> createState() => FileBrowserPageState();
}

class FileBrowserPageState extends State<FileBrowserPage> {
  bool _loading = true;
  String? _errorMessage;
  List<FileSystemEntity> _entries = <FileSystemEntity>[];
  FilesTabRefreshScopeState? _filesTabRefreshHost;
  final FocusNode _gridFocusNode = FocusNode(debugLabel: 'FileBrowserGrid');
  final FileExportShareService _shareService = const FileExportShareService();
  int? _selectedEntryIndex;
  int _keyboardGridColumns = 1;
  static const double _desktopGridSpacing = 12;
  static const double _targetItemWidth = 180;
  static const double _minItemWidth = 160;
  static const int _maxColumns = 6;

  /// 滚到底时多留一截，避免底部 SnackBar 等盖住最后一排 cell 的文件名。
  static const double _scrollBottomComfortGap = 96;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void didUpdateWidget(covariant FileBrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directoryPath != widget.directoryPath) {
      _loadEntries();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final FilesTabRefreshScopeState? host = FilesTabRefreshScope.maybeOf(
      context,
    );
    if (host != _filesTabRefreshHost) {
      _filesTabRefreshHost?.unregisterRefresh(_onFilesTabExternalRefresh);
      _filesTabRefreshHost = host;
      _filesTabRefreshHost?.registerRefresh(_onFilesTabExternalRefresh);
    }
  }

  Future<void> _onFilesTabExternalRefresh() => refreshEntries();

  @override
  void dispose() {
    _filesTabRefreshHost?.unregisterRefresh(_onFilesTabExternalRefresh);
    _gridFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final dir = Directory(widget.directoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final entries = (await dir.list().toList()).where((e) {
        final base = _entityName(e);
        return base.isEmpty || !base.startsWith('.');
      }).toList();
      entries.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir != bIsDir) {
          return aIsDir ? -1 : 1;
        }
        final aName = _entityName(a);
        final bName = _entityName(b);
        return compareFilenameNatural(aName, bName);
      });

      if (!mounted) return;
      final String? selectedPath = _currentSelectedPath();
      setState(() {
        _entries = entries;
        _selectedEntryIndex = _nextSelectedIndex(entries, selectedPath);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '读取目录失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> refreshEntries() async {
    await _loadEntries();
  }

  /// 删除成功后从内存列表拿掉该项，避免再走 `_loadEntries` 的全屏 loading + 重复读盘。
  /// 与 iOS `deleteRows` 同属「局部更新」；若要动画可再换 `AnimatedList` / 自定义 grid 过渡。
  void _removeEntryFromList(FileSystemEntity removed) {
    if (!mounted) {
      return;
    }
    final path = removed.path;
    setState(() {
      _entries.removeWhere((e) => e.path == path);
      _selectedEntryIndex = _nextSelectedIndex(
        _entries,
        _currentSelectedPath(),
      );
    });
  }

  String? _currentSelectedPath() {
    final int? index = _selectedEntryIndex;
    if (index == null || index < 0 || index >= _entries.length) {
      return null;
    }
    return _entries[index].path;
  }

  String _entityName(FileSystemEntity entity) {
    final path = entity.path;
    final separator = Platform.pathSeparator;
    final index = path.lastIndexOf(separator);
    return index == -1 ? path : path.substring(index + 1);
  }

  int? _nextSelectedIndex(
    List<FileSystemEntity> entries,
    String? preferredPath,
  ) {
    if (entries.isEmpty) {
      return null;
    }
    if (preferredPath != null) {
      final int preferredIndex = entries.indexWhere(
        (FileSystemEntity e) => e.path == preferredPath,
      );
      if (preferredIndex >= 0) {
        return preferredIndex;
      }
    }
    final int firstImageIndex = entries.indexWhere(
      (FileSystemEntity e) =>
          e is File &&
          classifyFileBrowserEntry(e) == FileBrowserEntryKind.image,
    );
    return firstImageIndex >= 0 ? firstImageIndex : 0;
  }

  void _selectEntry(int index) {
    if (index < 0 || index >= _entries.length) {
      return;
    }
    setState(() {
      _selectedEntryIndex = index;
    });
    _gridFocusNode.requestFocus();
  }

  void _openDirectory(Directory directory) {
    final title = _entityName(directory);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            FileBrowserPage(directoryPath: directory.path, pageTitle: title),
      ),
    );
  }

  /// 当前目录下「图片」文件路径，按自然序排序（与网格列表一致）。
  List<String> _collectImagePathsSorted() {
    final List<FileSystemEntity> images = _entries
        .where(
          (FileSystemEntity e) =>
              e is File &&
              classifyFileBrowserEntry(e) == FileBrowserEntryKind.image,
        )
        .toList();
    images.sort(
      (FileSystemEntity a, FileSystemEntity b) =>
          compareFilenameNatural(_entityName(a), _entityName(b)),
    );
    return images.map((FileSystemEntity e) => e.path).toList();
  }

  void _openImageGallery(File tapped) {
    final List<String> paths = _collectImagePathsSorted();
    if (paths.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前目录没有可预览的图片')));
      return;
    }
    final int initial = paths.indexOf(tapped.path);
    final int initialIndex = initial >= 0 ? initial : 0;
    if (localImageGalleryUseSwipeDialog) {
      showLocalSwipeImageGallery(
        context,
        imagePaths: paths,
        initialIndex: initialIndex,
      );
      return;
    }
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => LocalImageGalleryPage(
          imagePaths: paths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _handleEntryTap(FileSystemEntity entry) {
    if (entry is Directory) {
      _openDirectory(entry);
      return;
    }
    final kind = classifyFileBrowserEntry(entry);
    if (kind == FileBrowserEntryKind.image && entry is File) {
      _openImageGallery(entry);
    } else if (entry is File && filePathSupportsTextPreview(entry.path)) {
      final String name = _entityName(entry);
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              TextFilePreviewPage(filePath: entry.path, title: name),
        ),
      );
    } else {
      // document：PDF / Office 等仍为占位
      debugPrint(
        'PicData-Flutter/lib/pages/files/file_browser_page.dart#_handleEntryTap: 非文本文档预览待开发 path=${entry.path}',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该类型文档预览暂未支持')));
    }
  }

  KeyEventResult _handleGridKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return _openSelectedEntry();
    }
    return _moveSelectionWithKey(key);
  }

  KeyEventResult _openSelectedEntry() {
    final int? index = _selectedEntryIndex;
    if (index == null || index < 0 || index >= _entries.length) {
      return KeyEventResult.ignored;
    }
    _handleEntryTap(_entries[index]);
    return KeyEventResult.handled;
  }

  KeyEventResult _moveSelectionWithKey(LogicalKeyboardKey key) {
    final int? current = _selectedEntryIndex;
    if (current == null || _entries.isEmpty) {
      return KeyEventResult.ignored;
    }
    final int columns = _keyboardGridColumns.clamp(1, _maxColumns);
    final Map<LogicalKeyboardKey, int> deltas = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.arrowLeft: -1,
      LogicalKeyboardKey.arrowRight: 1,
      LogicalKeyboardKey.arrowUp: -columns,
      LogicalKeyboardKey.arrowDown: columns,
    };
    final int? delta = deltas[key];
    if (delta == null) {
      return KeyEventResult.ignored;
    }
    _selectEntry((current + delta).clamp(0, _entries.length - 1));
    return KeyEventResult.handled;
  }

  Future<void> _showShareDialog() async {
    final PicSetDownloadRecord? setRecord = await PicSetDownloadRecordStore
        .instance
        .tryGetRecordByLocalDirectoryPath(widget.directoryPath);
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('分享'),
          content: const Text('请选择操作'),
          actions: [
            if (_canOpenPicDetail(setRecord))
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openPicDetailPage(setRecord);
                },
                child: const Text('查看套图详情'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showZipShareDialog();
              },
              child: const Text('压缩包分享'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showPdfShareDialog();
              },
              child: const Text('PDF 分享'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _openCurrentFolderInSystem();
              },
              child: const Text('打开本地文件夹'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  bool _canOpenPicDetail(PicSetDownloadRecord? record) {
    return record != null && record.contentHref.trim().isNotEmpty;
  }

  void _openPicDetailPage(PicSetDownloadRecord? record) {
    if (!_canOpenPicDetail(record)) {
      _showSnackBar('当前文件夹没有关联的套图详情');
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PicDetailPage(
          content: record!.toPicContent(
            isDownloaded: record.status == PicSetDownloadTaskStatus.completed,
          ),
          host: record.host.toLoosePicHost(),
        ),
      ),
    );
  }

  Future<void> _showZipShareDialog() async {
    final String folderName = _currentFolderName();
    final _ShareInput? input = await _showFileNameDialog(
      title: '压缩包分享',
      message: '请输入压缩包文件名和密码',
      defaultFileName: '$folderName.zip',
      confirmText: '去压缩',
      showPassword: true,
    );
    if (input == null) {
      return;
    }
    await _runExportShare(
      preparingMessage: '正在压缩...',
      successMessage: '压缩完成',
      createFile: () => _shareService.createZipFromDirectory(
        directoryPath: widget.directoryPath,
        fileName: input.fileName,
        password: input.password,
      ),
      shareTitle: _ensureExtension(input.fileName, 'zip'),
    );
  }

  Future<void> _showPdfShareDialog() async {
    final List<String> imagePaths = _collectImagePathsSorted();
    if (imagePaths.isEmpty) {
      _showSnackBar('当前目录没有可生成 PDF 的图片');
      return;
    }

    final _ShareInput? input = await _showFileNameDialog(
      title: 'PDF 分享',
      message: '将当前目录图片按自然顺序生成 PDF',
      defaultFileName: '${_currentFolderName()}.pdf',
      confirmText: '创建PDF',
      showPassword: false,
    );
    if (input == null) {
      return;
    }
    await _runExportShare(
      preparingMessage: '正在创建 PDF...',
      successMessage: 'PDF 创建完成（当前 PDF 未加密）',
      createFile: () => _shareService.createPdfFromImages(
        imagePaths: imagePaths,
        fileName: input.fileName,
      ),
      shareTitle: _ensureExtension(input.fileName, 'pdf'),
    );
  }

  Future<_ShareInput?> _showFileNameDialog({
    required String title,
    required String message,
    required String defaultFileName,
    required String confirmText,
    required bool showPassword,
  }) async {
    final TextEditingController fileNameController = TextEditingController(
      text: defaultFileName,
    );
    final TextEditingController passwordController = TextEditingController(
      text: FileExportShareService.defaultPassword,
    );
    final _ShareInput? input = await showDialog<_ShareInput>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(message)),
            const SizedBox(height: 16),
            TextField(
              controller: fileNameController,
              decoration: const InputDecoration(labelText: '文件名'),
              textInputAction: showPassword
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: showPassword
                  ? null
                  : (_) => Navigator.of(
                      ctx,
                    ).pop(_ShareInput(fileName: fileNameController.text)),
            ),
            if (showPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: '密码'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.of(ctx).pop(
                  _ShareInput(
                    fileName: fileNameController.text,
                    password: passwordController.text,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              _ShareInput(
                fileName: fileNameController.text,
                password: showPassword ? passwordController.text : null,
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    fileNameController.dispose();
    passwordController.dispose();
    return input;
  }

  Future<void> _runExportShare({
    required String preparingMessage,
    required String successMessage,
    required Future<File> Function() createFile,
    required String shareTitle,
  }) async {
    _showSnackBar(preparingMessage);
    try {
      final File file = await createFile();
      if (!mounted) {
        return;
      }
      _showSnackBar(successMessage);
      await _shareService.shareFile(file: file, title: shareTitle);
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint(
        'PicData-Flutter/lib/pages/files/file_browser_page.dart#_runExportShare: failed error=$e',
      );
      _showSnackBar('分享准备失败: $e');
    }
  }

  String _currentFolderName() {
    final String normalized = widget.directoryPath.replaceAll(
      RegExp(r'[/\\]+$'),
      '',
    );
    final String name = normalized.split(RegExp(r'[/\\]')).last;
    return name.isEmpty ? widget.pageTitle : name;
  }

  String _ensureExtension(String fileName, String extension) {
    final String trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return '${_currentFolderName()}.$extension';
    }
    return trimmed.toLowerCase().endsWith('.$extension')
        ? trimmed
        : '$trimmed.$extension';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCurrentFolderInSystem() async {
    await openLocalFolderInSystem(context, widget.directoryPath);
  }

  Future<void> _showEntryContextMenu(
    FileSystemEntity entry,
    Offset globalPosition,
  ) async {
    final overlayState = Navigator.of(context).overlay;
    if (overlayState == null) {
      return;
    }
    final overlay = overlayState.context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    );
    final chosen = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline),
            title: Text('删除'),
          ),
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    if (chosen == 'delete') {
      await _confirmDeleteEntry(entry);
    }
  }

  Future<void> _confirmDeleteEntry(FileSystemEntity entry) async {
    final name = _entityName(entry);
    final isDir = entry is Directory;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除确认'),
        content: Text(isDir ? '确定删除文件夹「$name」及其中的全部内容吗？' : '确定删除文件「$name」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _deleteEntry(entry);
    }
  }

  Future<void> _deleteEntry(FileSystemEntity entry) async {
    final label = _entityName(entry);
    try {
      if (entry is Directory) {
        await entry.delete(recursive: true);
      } else if (entry is File) {
        await entry.delete();
      } else {
        await entry.delete();
      }
      final int removedRecords = await PicSetDownloadRecordStore.instance
          .removeRecordsUnderLocalPath(entry.path);
      if (removedRecords == 0) {
        await PicSetDownloadRecordStore.instance.syncImageProgressFromDisk();
      }
      if (!mounted) {
        return;
      }
      _removeEntryFromList(entry);
      if (!mounted) {
        return;
      }
      final String suffix = removedRecords > 0
          ? '，并清理 $removedRecords 条下载记录'
          : '';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除：$label$suffix')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      debugPrint(
        'PicData-Flutter/lib/pages/files/file_browser_page.dart#_deleteEntry: failed path=${entry.path} error=$e',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => debugPrintPageBackdoorInfo(
            className: 'FileBrowserPage',
            filePath: 'PicData-Flutter/lib/pages/files/file_browser_page.dart',
          ),
          child: Text(widget.pageTitle),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadEntries();
            },
          ),
          IconButton(
            tooltip: '分享',
            icon: const Icon(Icons.share),
            onPressed: _showShareDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_entries.isEmpty) {
      return const Center(child: Text('当前目录为空'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = isCompactGalleryGrid(context);
        final horizontalInset = fileBrowserHorizontalInset(context);
        final maxWidth = (constraints.maxWidth - 2 * horizontalInset)
            .clamp(0.0, double.infinity)
            .toDouble();
        final gridSpacing = galleryGridSpacing(context);
        final columns = compact
            ? 3.clamp(1, _maxColumns)
            : (maxWidth / (_targetItemWidth + _desktopGridSpacing))
                  .floor()
                  .clamp(1, _maxColumns);
        _keyboardGridColumns = columns;
        final gridWidth = compact
            ? columns * (_targetItemWidth + gridSpacing) - gridSpacing
            : columns * (_targetItemWidth + _desktopGridSpacing) -
                  _desktopGridSpacing;
        final sidePadding = ((maxWidth - gridWidth) / 2)
            .clamp(0, double.infinity)
            .toDouble();
        final cellWidth =
            ((maxWidth - sidePadding * 2 - (columns - 1) * gridSpacing) /
            columns);
        // 桌面：过窄时用语义宽度稳住纵向比例；手机三列用真实 cell 宽度。
        final stableWidth = compact
            ? cellWidth
            : (cellWidth < _minItemWidth ? _minItemWidth : cellWidth);
        // 上方近似方形缩略图区 + 下方文件名（两行 + 内边距）
        final childAspectRatio = stableWidth / (stableWidth + 52);
        final bottomPadding =
            12 + MediaQuery.paddingOf(context).bottom + _scrollBottomComfortGap;

        return Focus(
          focusNode: _gridFocusNode,
          autofocus: true,
          onKeyEvent: _handleGridKeyEvent,
          child: RefreshIndicator(
            onRefresh: _loadEntries,
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalInset + sidePadding,
                12,
                horizontalInset + sidePadding,
                bottomPadding,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: gridSpacing,
                mainAxisSpacing: gridSpacing,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: _entries.length,
              itemBuilder: (context, index) => _buildGridItem(index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridItem(int index) {
    final entry = _entries[index];
    final name = _entityName(entry);
    final kind = classifyFileBrowserEntry(entry);
    return _FileGridItem(
      key: ValueKey<String>(entry.path),
      name: name,
      path: entry.path,
      kind: kind,
      selected: index == _selectedEntryIndex,
      onTap: () {
        _selectEntry(index);
        _handleEntryTap(entry);
      },
      onFocus: () => _selectEntry(index),
      onOpenContextMenu: (globalPosition) =>
          _showEntryContextMenu(entry, globalPosition),
    );
  }
}

class _FileGridItem extends StatelessWidget {
  const _FileGridItem({
    super.key,
    required this.name,
    required this.path,
    required this.kind,
    required this.selected,
    required this.onTap,
    required this.onFocus,
    required this.onOpenContextMenu,
  });

  final String name;
  final String path;
  final FileBrowserEntryKind kind;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final void Function(Offset globalPosition) onOpenContextMenu;

  static Offset _cellCenterGlobal(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return Offset.zero;
    }
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            onOpenContextMenu(details.globalPosition),
        child: InkWell(
          onTap: onTap,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              onFocus();
            }
          },
          onLongPress: () => onOpenContextMenu(_cellCenterGlobal(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  child: _FileGridThumbnail(kind: kind, path: path),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareInput {
  const _ShareInput({required this.fileName, this.password});

  final String fileName;
  final String? password;
}

class _FileGridThumbnail extends StatelessWidget {
  const _FileGridThumbnail({required this.kind, required this.path});

  final FileBrowserEntryKind kind;
  final String path;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case FileBrowserEntryKind.folder:
        return Center(
          child: Icon(
            Icons.folder_rounded,
            size: 56,
            color: Colors.amber.shade700,
          ),
        );
      case FileBrowserEntryKind.document:
        return Center(
          child: Icon(
            Icons.description_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      case FileBrowserEntryKind.image:
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
            );
          },
        );
    }
  }
}
