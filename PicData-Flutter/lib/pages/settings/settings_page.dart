import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/services/proxy_settings_service.dart';

/// 大屏（尤其 macOS）上避免 AlertDialog 默认过宽，保持表单比例紧凑。
const BoxConstraints _kSettingsDialogConstraints = BoxConstraints(
  minWidth: 280,
  maxWidth: 400,
);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _proxyHostController = TextEditingController();
  final TextEditingController _proxyPortController = TextEditingController();
  String _currentRootPath = '';
  bool _saving = false;

  String _proxySubtitle() {
    final s = ProxySettingsService.instance;
    if (!s.isProxyEnabled) {
      return '直连（未使用代理）';
    }
    return '${s.proxyHost}:${s.proxyPort}';
  }

  List<_SettingItem> _buildSettingItems() {
    return <_SettingItem>[
      _SettingItem(
        title: '下载路径',
        subtitle: _currentRootPath.isEmpty ? '加载中...' : _currentRootPath,
        onTap: _saving ? null : _showPathEditorDialog,
      ),
      _SettingItem(
        title: '网络代理',
        subtitle: _proxySubtitle(),
        onTap: _saving ? null : _showProxyEditorDialog,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    DownloadFileService.instance.rootPathNotifier.addListener(_onRootPathChanged);
    ProxySettingsService.instance.proxyHostNotifier.addListener(_onProxyChanged);
    ProxySettingsService.instance.proxyPortNotifier.addListener(_onProxyChanged);
    _syncProxyFieldsFromService();
    _loadRootPath();
  }

  void _onProxyChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _syncProxyFieldsFromService() {
    final s = ProxySettingsService.instance;
    _proxyHostController.text = s.proxyHost;
    final p = s.proxyPort;
    _proxyPortController.text = p == null ? '' : '$p';
  }

  @override
  void dispose() {
    DownloadFileService.instance.rootPathNotifier.removeListener(
      _onRootPathChanged,
    );
    ProxySettingsService.instance.proxyHostNotifier.removeListener(
      _onProxyChanged,
    );
    ProxySettingsService.instance.proxyPortNotifier.removeListener(
      _onProxyChanged,
    );
    _pathController.dispose();
    _proxyHostController.dispose();
    _proxyPortController.dispose();
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

  Future<void> _saveProxy() async {
    final host = _proxyHostController.text;
    final portRaw = _proxyPortController.text.trim();
    final port = portRaw.isEmpty ? null : int.tryParse(portRaw);

    if (ProxySettingsService.isDirect(host, port)) {
      setState(() {
        _saving = true;
      });
      try {
        await ProxySettingsService.instance.setProxyHostAndPort(host: '', port: null);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('代理设置已保存（直连）')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _saving = false;
          });
        }
      }
      return;
    }

    if (!ProxySettingsService.isValidHost(host) ||
        !ProxySettingsService.isValidPort(port)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写有效的主机与端口（1–65535）')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      await ProxySettingsService.instance.setProxyHostAndPort(
        host: host,
        port: port,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('代理设置已保存')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _showProxyEditorDialog() async {
    _syncProxyFieldsFromService();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          constraints: _kSettingsDialogConstraints,
          title: const Text('网络代理'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  '上面填代理地址，下面填数字端口，无需输入英文冒号「:」。'
                  '任一侧留空并保存即为直连。仅影响本应用内 HTTP 请求。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proxyHostController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '主机',
                    hintText: '例如 127.0.0.1',
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proxyPortController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '端口（纯数字）',
                    hintText: '例如 7897',
                  ),
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              _proxyHostController.text =
                                  ProxySettingsService.kDefaultProxyHost;
                              _proxyPortController.text =
                                  '${ProxySettingsService.kDefaultProxyPort}';
                            },
                      child: const Text('一键填入本机常用'),
                    ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () {
                              _proxyHostController.clear();
                              _proxyPortController.clear();
                            },
                      child: const Text('清空（直连）'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      await _saveProxy();
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPathEditorDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          constraints: _kSettingsDialogConstraints,
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
              onPressed: _saving ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      await _resetRootPath();
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                    },
              child: const Text('恢复默认'),
            ),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      await _saveRootPath();
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
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
        separatorBuilder: (BuildContext context, int index) =>
            const Divider(height: 1),
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
