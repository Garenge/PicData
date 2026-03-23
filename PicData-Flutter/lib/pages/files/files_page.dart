import 'package:flutter/material.dart';

import 'package:pic_data/services/download_file_service.dart';
import 'file_browser_page.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key, required this.refreshSignal});

  final int refreshSignal;

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  String _rootPath = '';
  final GlobalKey<FileBrowserPageState> _browserPageKey =
      GlobalKey<FileBrowserPageState>();

  @override
  void initState() {
    super.initState();
    _initializeRootPath();
    DownloadFileService.instance.rootPathNotifier.addListener(_onRootPathChanged);
  }

  @override
  void dispose() {
    DownloadFileService.instance.rootPathNotifier.removeListener(
      _onRootPathChanged,
    );
    super.dispose();
  }

  Future<void> _initializeRootPath() async {
    final path = await DownloadFileService.instance.getRootPath();
    if (!mounted) return;
    setState(() {
      _rootPath = path;
    });
  }

  void _onRootPathChanged() {
    final path = DownloadFileService.instance.rootPathNotifier.value;
    if (!mounted || path.isEmpty || path == _rootPath) return;
    _popFileNavigatorToRoot();
    setState(() {
      _rootPath = path;
    });
  }

  void _popFileNavigatorToRoot() {
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.popUntil((Route<dynamic> route) => route.isFirst);
    }
  }

  @override
  void didUpdateWidget(covariant FilesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) {
      _refreshCurrentDirectory();
    }
  }

  Future<void> _refreshCurrentDirectory() async {
    if (_rootPath.isEmpty) {
      await _initializeRootPath();
    } else {
      _popFileNavigatorToRoot();
      await _browserPageKey.currentState?.refreshEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_rootPath.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FileBrowserPage(
      key: _browserPageKey,
      directoryPath: _rootPath,
      pageTitle: '文件',
    );
  }
}
