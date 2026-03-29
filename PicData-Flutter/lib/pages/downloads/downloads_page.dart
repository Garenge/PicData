import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/services/open_local_folder.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  Future<void> _openDownloadsRootInSystem(BuildContext context) async {
    final path = await DownloadFileService.instance.getRootPath();
    if (!context.mounted) return;
    await openLocalFolderInSystem(context, path);
  }

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
        actions: [
          IconButton(
            tooltip: supportsOpenLocalFolderInSystem ? '打开下载文件夹' : '打开本地文件夹（仅桌面系统）',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () => _openDownloadsRootInSystem(context),
          ),
        ],
      ),
      body: const Center(child: Text('下载页面')),
    );
  }
}
