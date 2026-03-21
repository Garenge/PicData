import 'package:flutter/material.dart';

import '../../services/download_file_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _pathController = TextEditingController();
  String _currentRootPath = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRootPath();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('下载根目录'),
            const SizedBox(height: 8),
            Text(
              _currentRootPath.isEmpty ? '加载中...' : _currentRootPath,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入新的下载路径',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _saving ? null : _saveRootPath,
                  child: const Text('保存路径'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _saving ? null : _resetRootPath,
                  child: const Text('恢复默认'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
