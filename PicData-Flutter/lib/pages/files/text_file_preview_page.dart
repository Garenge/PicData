import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';

const String _logPath = 'PicData-Flutter/lib/pages/files/text_file_preview_page.dart';

/// 避免一次性读入过大文件；超出部分截断并在页内提示。
const int kTextFilePreviewMaxBytes = 1500000;

class TextFilePreviewPage extends StatefulWidget {
  const TextFilePreviewPage({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<TextFilePreviewPage> createState() => _TextFilePreviewPageState();
}

class _TextFilePreviewPageState extends State<TextFilePreviewPage> {
  bool _loading = true;
  String? _error;
  String? _text;
  bool _truncated = false;
  int? _totalBytes;

  /// 与 [Scrollbar] 共用，避免嵌套在 [Column]/[Expanded] 下误用 [PrimaryScrollController] 导致无 [ScrollPosition]。
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final File file = File(widget.filePath);
      if (!await file.exists()) {
        if (!mounted) {
          return;
        }
        setState(() {
          _loading = false;
          _error = '文件不存在';
        });
        return;
      }
      final int len = await file.length();
      _totalBytes = len;
      final int maxLen = len > kTextFilePreviewMaxBytes ? kTextFilePreviewMaxBytes : len;
      final BytesBuilder builder = BytesBuilder(copy: false);
      await for (final List<int> chunk in file.openRead(0, maxLen)) {
        builder.add(chunk);
      }
      final Uint8List raw = builder.takeBytes();
      final String text = utf8.decode(raw, allowMalformed: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _text = text;
        _truncated = len > kTextFilePreviewMaxBytes;
      });
    } catch (e, st) {
      // ignore: avoid_print
      print('$_logPath#_load: failed path=${widget.filePath} error=$e');
      // ignore: avoid_print
      print('  stack=$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '读取失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => debugPrintPageBackdoorInfo(
            className: 'TextFilePreviewPage',
            filePath: _logPath,
          ),
          child: Text(
            widget.title,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final String text = _text ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_truncated)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                '文件较大，仅显示前 $kTextFilePreviewMaxBytes 字节'
                '${_totalBytes != null ? '（共 $_totalBytes 字节）' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              primary: false,
              padding: const EdgeInsets.all(16),
              child: SelectionArea(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
