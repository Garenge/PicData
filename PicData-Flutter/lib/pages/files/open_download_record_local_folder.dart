import 'package:flutter/material.dart';

import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/pages/files/file_browser_page.dart';

/// 根据记录中的 [PicSetDownloadRecord.localDirRelativeToApplicationDocuments] 打开 [FileBrowserPage]。
Future<void> pushFileBrowserForDownloadRecord(
  BuildContext context,
  PicSetDownloadRecord record,
) async {
  final String rel = record.localDirRelativeToApplicationDocuments.trim();
  if (rel.isEmpty) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本地目录路径无效')),
    );
    return;
  }

  final String abs = await DownloadFileService.instance
      .absolutePathFromApplicationDocumentsRelative(rel);
  if (!context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => FileBrowserPage(
        directoryPath: abs,
        pageTitle: record.title,
      ),
    ),
  );
}
