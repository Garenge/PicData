import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';

import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/models/home_entry.dart';
import 'package:pic_data/services/pic_net_service.dart';
import 'package:pic_data/debug/page_backdoor.dart';
import 'hosts/hosts_drawer.dart';
import 'gallery/tag_gallery_page.dart';

/// 首页展示的两种视图模式：
/// - [HomeViewType.tags]：用标签云（`ActionChip`）展示入口；
/// - [HomeViewType.list]：用可按字母索引跳转的列表展示入口。
enum HomeViewType { tags, list }

/// 应用的导航首页。
///
/// 左侧可以选择数据源（`PicHost`），右侧根据当前 Host 的入口配置和搜索关键词，
/// 组合出用于浏览的入口列表，并支持在「标签视图」和「列表视图」之间切换。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// `HomePage` 对应的可变状态。
class _HomePageState extends State<HomePage> {
  /// 当前选中的首页展示模式（标签 / 列表）。
  HomeViewType _viewType = HomeViewType.tags;

  /// 列表模式下用于控制滚动和字母索引快速跳转的控制器。
  final ScrollController _listController = ScrollController();

  /// 当前选中的图站配置（如果为空则回退到 `PicNetService.instance.selectedHost`）。
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

  /// 处理入口点击：打印日志，并根据当前 Host 跳转到对应的图集列表页。
  void _onEntryTap(HomeEntry entry) {
    // ignore: avoid_print
    print('Tap HomeEntry -> title: ${entry.title}, url: ${entry.url}');
    final selectedHost = _selectedHost ?? PicNetService.instance.selectedHost;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TagGalleryPage(entry: entry, host: selectedHost),
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
        title: GestureDetector(
          onTap: () => debugPrintPageBackdoorInfo(
            className: 'HomePage',
            filePath: 'PicData-Flutter/lib/pages/Home/home_page.dart',
          ),
          child: const Text('导航'),
        ),
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

  /// 构建「标签云」形式的入口视图：使用 `Wrap + ActionChip` 展示所有入口。
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

  /// 构建「列表 + 右侧字母索引栏」形式的入口视图。
  ///
  /// 左侧是可滚动列表，右侧是字母索引栏，点击索引会通过 [_listController]
  /// 平滑滚动到对应首条记录的位置。
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
