import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';

import '../services/pic_net_service.dart';

enum HomeViewType { tags, list }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeViewType _viewType = HomeViewType.tags;
  final ScrollController _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _onKeyTap(String key) {
    // ignore: avoid_print
    print('Key tapped: $key');
  }

  @override
  Widget build(BuildContext context) {
    final searchKeys = PicNetService.instance.globalSearchKeys;

    // 加载完成后，简单输出 searchKeys，方便调试和后续使用
    // ignore: avoid_print
    print('PicNetConfig searchKeys count: ${searchKeys.length}');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '导航站点',
          icon: const Icon(Icons.public),
          onPressed: () {
            // TODO: 实现后续导航逻辑
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
      body: _viewType == HomeViewType.tags
          ? _buildTagsView(searchKeys)
          : _buildListView(searchKeys),
    );
  }

  Widget _buildTagsView(List<String> searchKeys) {
    if (searchKeys.isEmpty) {
      return const Center(child: Text('暂无标签'));
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: searchKeys
              .map(
                (k) => GestureDetector(
                  onTap: () => _onKeyTap(k),
                  child: Chip(label: Text(k)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildListView(List<String> searchKeys) {
    if (searchKeys.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    // 此处不再二次排序，保持 PicNetService 中按拼音排序后的顺序
    final sortedKeys = [...searchKeys];
    final Map<String, int> firstIndexByLetter = <String, int>{};

    String indexLetterFor(String key) {
      final trimmed = key.trim();
      if (trimmed.isEmpty) return '#';
      final pinyin = PinyinHelper.getShortPinyin(trimmed).toUpperCase();
      if (pinyin.isEmpty) return '#';
      final first = pinyin[0];
      final isLatin = RegExp(r'[A-Z]').hasMatch(first);
      return isLatin ? first : '#';
    }

    for (var i = 0; i < sortedKeys.length; i++) {
      final letter = indexLetterFor(sortedKeys[i]);
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
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final title = sortedKeys[index];
              return ListTile(
                title: Text(title),
                onTap: () => _onKeyTap(title),
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
