import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/services/download_file_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _pathController = TextEditingController();
  String _currentRootPath = '';
  bool _saving = false;

  List<_SettingItem> _buildSettingItems() {
    return <_SettingItem>[
      _SettingItem(
        title: '下载路径',
        subtitle: _currentRootPath.isEmpty ? '加载中...' : _currentRootPath,
        onTap: _saving ? null : _showPathEditorDialog,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    DownloadFileService.instance.rootPathNotifier.addListener(_onRootPathChanged);
    _loadRootPath();
  }

  @override
  void dispose() {
    DownloadFileService.instance.rootPathNotifier.removeListener(
      _onRootPathChanged,
    );
    _pathController.dispose();
    super.dispose();
  }

  void _onRootPathChanged() {
    final latestPath = DownloadFileService.instance.rootPathNotifier.value;
    if (!mounted || latestPath.isEmpty || latestPath == _currentRootPath) return;
    setState(() {
      _currentRootPath = latestPath;
      _pathController.text = latestPath;
    });
  }

  Future<void> _loadRootPath() async {
    final path = await DownloadFileService.instance.getRootPath();
    if (!mounted) return;
    setState(() {
      _currentRootPath = path;
      _pathController.text = path;
    });
  }

  Future<void> _saveRootPath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _saving = true;
    });
    try {
      await DownloadFileService.instance.setRootPath(path);
      await _loadRootPath();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载目录已更新')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _resetRootPath() async {
    setState(() {
      _saving = true;
    });
    try {
      await DownloadFileService.instance.resetToDefaultRootPath();
      await _loadRootPath();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复默认下载目录')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _showPathEditorDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('下载路径'),
          content: TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '输入新的下载路径',
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      await _resetRootPath();
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
              child: const Text('恢复默认'),
            ),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      await _saveRootPath();
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildSettingItems();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => debugPrintPageBackdoorInfo(
            className: 'SettingsPage',
            filePath: 'PicData-Flutter/lib/pages/settings/settings_page.dart',
          ),
          child: const Text('设置'),
        ),
      ),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            title: Text(item.title),
            subtitle: Text(item.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: item.onTap,
          );
        },
      ),
    );
  }
}

class _SettingItem {
  const _SettingItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}
