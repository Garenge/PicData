import 'package:flutter/material.dart';

import '../../models/home_entry.dart';
import '../../services/net_client.dart';
import '../../services/web_page_parser.dart';

/// 某个标签 / 入口对应的图集列表页面。
///
/// 当前实现：进入页面后先请求入口 URL，对网页内容做一次简单解析，
/// 把结果文本打印在页面上，后续再替换为真实图集展示逻辑。
class TagGalleryPage extends StatefulWidget {
  const TagGalleryPage({super.key, required this.entry});

  /// 当前选中的首页入口（包含标题和 URL）
  final HomeEntry entry;

  @override
  State<TagGalleryPage> createState() => _TagGalleryPageState();
}

class _TagGalleryPageState extends State<TagGalleryPage> {
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadPageContent();
  }

  Future<String> _loadPageContent() async {
    final url = widget.entry.url;
    if (url.isEmpty) {
      return '当前入口没有配置 URL';
    }

    // 1. 通过网络工具类请求网页内容
    final html = await NetClient.instance.getText(url);

    // 2. 控制台打印一份原始内容长度，方便调试
    // ignore: avoid_print
    print('Loaded html from $url, length=${html.length}');

    // 3. 通过解析工具类转成可读文本
    final parser = const WebPageParser();
    final text = parser.extractReadableText(html);

    if (text.isEmpty) {
      return '网页内容解析结果为空（原始长度：${html.length}）';
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry.title)),
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final stack = snapshot.stackTrace;
            // ignore: avoid_print
            print('TagGalleryPage _loadPageContent ERROR for url=${widget.entry.url}');
            // ignore: avoid_print
            print('  errorType=${error.runtimeType}');
            // ignore: avoid_print
            print('  error=$error');
            if (stack != null) {
              // ignore: avoid_print
              print('  stackTrace=$stack');
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  '加载失败：${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final content = snapshot.data ?? '';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

