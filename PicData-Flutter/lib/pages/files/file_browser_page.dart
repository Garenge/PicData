import 'dart:io';

import 'package:flutter/material.dart';

import '../../debug/page_backdoor.dart';

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
        final aName = _entityName(a).toLowerCase();
        final bName = _entityName(b).toLowerCase();
        return aName.compareTo(bName);
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

  bool get _supportsOpenLocalFolder =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

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
    if (!_supportsOpenLocalFolder) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前设备不支持直接打开本地文件夹')));
      return;
    }

    try {
      if (Platform.isMacOS) {
        await Process.start('open', [widget.directoryPath]);
      } else if (Platform.isWindows) {
        await Process.start('explorer', [widget.directoryPath]);
      } else if (Platform.isLinux) {
        await Process.start('xdg-open', [widget.directoryPath]);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开文件夹失败: $e')));
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
        final childAspectRatio = stableWidth / (stableWidth + 44);

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
              final isDir = entry is Directory;
              final name = _entityName(entry);
              return _FileGridItem(
                name: name,
                path: entry.path,
                isDirectory: isDir,
                onTap: isDir ? () => _openDirectory(entry) : null,
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
    required this.isDirectory,
    this.onTap,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isDirectory ? Icons.folder : Icons.insert_drive_file,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Spacer(),
              if (isDirectory)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.chevron_right, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
