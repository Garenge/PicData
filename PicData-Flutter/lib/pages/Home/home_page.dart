import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';

import '../../models/pic_net_models.dart';
import '../../models/home_entry.dart';
import '../../services/pic_net_service.dart';
import 'hosts_drawer.dart';
import 'tag_gallery_page.dart';

enum HomeViewType { tags, list }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeViewType _viewType = HomeViewType.tags;
  final ScrollController _listController = ScrollController();
  PicHost? _selectedHost;

  @override
  void initState() {
    super.initState();
    // 首次进入时同步当前服务
    _selectedHost = PicNetService.instance.selectedHost;
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _onEntryTap(HomeEntry entry) {
    // ignore: avoid_print
    print('Tap HomeEntry -> title: ${entry.title}, url: ${entry.url}');
    final selectedHost = _selectedHost ?? PicNetService.instance.selectedHost;

    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) => TagGalleryPage(
          entry: entry,
          host: selectedHost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hosts = PicNetService.instance.hosts;
    final selectedHost = _selectedHost ?? PicNetService.instance.selectedHost;

    // 优先使用当前选中服务的 searchKeys，若为空则回退到全局 searchKeys
    List<String> baseKeys;
    if (selectedHost != null && selectedHost.searchKeys.isNotEmpty) {
      baseKeys = [...selectedHost.searchKeys];
    } else {
      baseKeys = [...PicNetService.instance.globalSearchKeys];
    }

    // 按拼音排序，保持展示顺序稳定（仅对基础搜索词排序）
    baseKeys.sort((a, b) {
      final pa = PinyinHelper.getPinyinE(a, separator: '', defPinyin: a);
      final pb = PinyinHelper.getPinyinE(b, separator: '', defPinyin: b);
      return pa.compareTo(pb);
    });

    // 在数据源前面补上当前 Host 的入口标题（PicNetConfig.hosts.urls.title）
    final List<HomeEntry> entries = <HomeEntry>[];
    final selectedSearchFormat = selectedHost?.searchFormat ?? '';
    final bool shouldEncode = selectedHost?.searchEncode == true;

    String buildSearchUrl(String title) {
      var value = title;
      if (shouldEncode) {
        value = Uri.encodeComponent(value);
      }
      if (selectedSearchFormat.isEmpty) {
        return '';
      }
      if (selectedSearchFormat.contains('%@')) {
        return selectedSearchFormat.replaceAll('%@', value);
      }
      // 兼容某些使用 %s 的配置
      if (selectedSearchFormat.contains('%s')) {
        return selectedSearchFormat.replaceAll('%s', value);
      }
      return selectedSearchFormat;
    }

    // 1. Host.urls -> 前缀入口
    final Set<String> existedTitles = <String>{};
    if (selectedHost != null && selectedHost.urls.isNotEmpty) {
      for (final u in selectedHost.urls) {
        final title = (u.title).trim();
        if (title.isEmpty || existedTitles.contains(title)) continue;
        existedTitles.add(title);
        entries.add(HomeEntry(title: title, url: u.url));
      }
    }

    // 2. searchKeys -> 使用 searchFormat 生成 URL
    for (final key in baseKeys) {
      final title = key.trim();
      if (title.isEmpty || existedTitles.contains(title)) continue;
      existedTitles.add(title);
      final url = buildSearchUrl(title);
      entries.add(HomeEntry(title: title, url: url));
    }

    // 简单输出当前数据源信息，方便调试
    // ignore: avoid_print
    print(
      'Home entries count: ${entries.length}, from host: ${selectedHost?.mark ?? 'global'}',
    );

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return IconButton(
              tooltip: '导航站点',
              icon: const Icon(Icons.public),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: const Text('导航'),
        actions: [
          IconButton(
            tooltip: _viewType == HomeViewType.tags ? '切换到列表' : '切换到标签',
            icon: Icon(
              _viewType == HomeViewType.tags ? Icons.list : Icons.layers,
            ),
            onPressed: () {
              setState(() {
                _viewType = _viewType == HomeViewType.tags
                    ? HomeViewType.list
                    : HomeViewType.tags;
              });
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: HostsDrawer(
            hosts: hosts,
            selectedHost: selectedHost,
            onHostTap: (host) {
              // ignore: avoid_print
              print('Host tapped: ${host.title} - ${host.hostUrl ?? ''}');
              PicNetService.instance.setSelectedHost(host);
              setState(() {
                _selectedHost = host;
              });
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
      body: _viewType == HomeViewType.tags
          ? _buildTagsView(entries)
          : _buildListView(entries),
    );
  }

  Widget _buildTagsView(List<HomeEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('暂无标签'));
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries
              .map(
                (e) => ActionChip(
                  label: Text(e.title),
                  onPressed: () => _onEntryTap(e),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildListView(List<HomeEntry> entries) {
    if (entries.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    // 此处不再二次排序，保持上游按拼音排序后的顺序
    final sortedEntries = [...entries];
    final Map<String, int> firstIndexByLetter = <String, int>{};

    String indexLetterFor(String title) {
      final trimmed = title.trim();
      if (trimmed.isEmpty) return '#';
      final pinyin = PinyinHelper.getShortPinyin(trimmed).toUpperCase();
      if (pinyin.isEmpty) return '#';
      final first = pinyin[0];
      final isLatin = RegExp(r'[A-Z]').hasMatch(first);
      return isLatin ? first : '#';
    }

    for (var i = 0; i < sortedEntries.length; i++) {
      final letter = indexLetterFor(sortedEntries[i].title);
      firstIndexByLetter.putIfAbsent(letter, () => i);
    }

    final indexLetters = firstIndexByLetter.keys.toList()
      ..sort((a, b) {
        if (a == '#') return -1;
        if (b == '#') return 1;
        return a.compareTo(b);
      });

    return Row(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _listController,
            itemExtent: 48,
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return ListTile(
                title: Text(entry.title),
                onTap: () => _onEntryTap(entry),
              );
            },
          ),
        ),
        SizedBox(
          width: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: indexLetters
                .map(
                  (letter) => GestureDetector(
                    onTap: () {
                      final targetIndex = firstIndexByLetter[letter];
                      if (targetIndex == null) return;
                      _listController.animateTo(
                        48.0 * targetIndex,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(letter, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
