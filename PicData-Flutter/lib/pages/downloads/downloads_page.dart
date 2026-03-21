import 'package:flutter/material.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下载')),
      body: const Center(child: Text('下载页面')),
    );
  }
}
