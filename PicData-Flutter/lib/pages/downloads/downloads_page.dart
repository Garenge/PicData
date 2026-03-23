import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => debugPrintPageBackdoorInfo(
            className: 'DownloadsPage',
            filePath: 'PicData-Flutter/lib/pages/downloads/downloads_page.dart',
          ),
          child: const Text('下载'),
        ),
      ),
      body: const Center(child: Text('下载页面')),
    );
  }
}
