import 'dart:io';

import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/pages/files/file_browser_entry_kind.dart';
import 'package:pic_data/services/open_local_folder.dart';
import 'package:pic_data/utils/filename_natural_compare.dart';

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
  static const double _gridSpacing = 12;
  static const double _targetItemWidth = 180;
  static const double _minItemWidth = 160;
  static const int _maxColumns = 6;

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

      final entries = await dir.list().toList();
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
      setState(() {
        _entries = entries;
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

  String _entityName(FileSystemEntity entity) {
    final path = entity.path;
    final separator = Platform.pathSeparator;
    final index = path.lastIndexOf(separator);
    return index == -1 ? path : path.substring(index + 1);
  }

  void _openDirectory(Directory directory) {
    final title = _entityName(directory);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => FileBrowserPage(
          directoryPath: directory.path,
          pageTitle: title,
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
    if (kind == FileBrowserEntryKind.image) {
      // TODO: 接入图片全屏预览（PhotoView / 画廊等）
      debugPrint(
        'PicData-Flutter/lib/pages/files/file_browser_page.dart#_handleEntryTap: 图片预览待开发 path=${entry.path}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片预览功能待开发')),
      );
    } else {
      // document：含常见办公文档与未识别扩展名（与列表图标一致）
      // TODO: 接入文档预览页面（PDF/WebView 等）
      debugPrint(
        'PicData-Flutter/lib/pages/files/file_browser_page.dart#_handleEntryTap: 文档预览待开发 path=${entry.path}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文档预览功能待开发')),
      );
    }
  }

  Future<void> _showShareDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('分享'),
          content: const Text('请选择操作'),
          actions: [
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

  Future<void> _openCurrentFolderInSystem() async {
    await openLocalFolderInSystem(context, widget.directoryPath);
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
        final maxWidth = constraints.maxWidth;
        final columns = (maxWidth / (_targetItemWidth + _gridSpacing))
            .floor()
            .clamp(1, _maxColumns);
        final gridWidth =
            columns * (_targetItemWidth + _gridSpacing) - _gridSpacing;
        final sidePadding = ((maxWidth - gridWidth) / 2)
            .clamp(0, double.infinity)
            .toDouble();
        final cellWidth =
            ((maxWidth - sidePadding * 2 - (columns - 1) * _gridSpacing) /
            columns);
        final stableWidth = cellWidth < _minItemWidth
            ? _minItemWidth
            : cellWidth;
        // 上方近似方形缩略图区 + 下方文件名（两行 + 内边距）
        final childAspectRatio = stableWidth / (stableWidth + 52);

        return RefreshIndicator(
          onRefresh: _loadEntries,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(sidePadding, 12, sidePadding, 12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: _gridSpacing,
              mainAxisSpacing: _gridSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final name = _entityName(entry);
              final kind = classifyFileBrowserEntry(entry);
              return _FileGridItem(
                name: name,
                path: entry.path,
                kind: kind,
                onTap: () => _handleEntryTap(entry),
              );
            },
          ),
        );
      },
    );
  }
}

class _FileGridItem extends StatelessWidget {
  const _FileGridItem({
    required this.name,
    required this.path,
    required this.kind,
    required this.onTap,
  });

  final String name;
  final String path;
  final FileBrowserEntryKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
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
    );
  }
}

class _FileGridThumbnail extends StatelessWidget {
  const _FileGridThumbnail({
    required this.kind,
    required this.path,
  });

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
