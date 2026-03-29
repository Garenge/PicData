import 'dart:io';

import 'package:flutter/material.dart';

bool get supportsOpenLocalFolderInSystem =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Opens [directoryPath] in the desktop file manager (Finder / Explorer / xdg-open).
Future<void> openLocalFolderInSystem(
  BuildContext context,
  String directoryPath,
) async {
  const logCtx = 'PicData-Flutter/lib/services/open_local_folder.dart';
  if (!supportsOpenLocalFolderInSystem) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('当前设备不支持直接打开本地文件夹')),
    );
    return;
  }

  try {
    if (Platform.isMacOS) {
      await Process.start('open', [directoryPath]);
    } else if (Platform.isWindows) {
      await Process.start('explorer', [directoryPath]);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [directoryPath]);
    }
  } catch (e) {
    if (!context.mounted) return;
    // ignore: avoid_print
    print('$logCtx#openLocalFolderInSystem: failed path=$directoryPath error=$e');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('打开文件夹失败: $e')));
  }
}
