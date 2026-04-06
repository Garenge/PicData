import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadFileService {
  DownloadFileService._internal();

  static final DownloadFileService instance = DownloadFileService._internal();

  static const String _customRootPathKey = 'download_custom_root_path';
  static const String _defaultFolderName = 'PicDownloads';

  SharedPreferences? _prefs;
  final ValueNotifier<String> rootPathNotifier = ValueNotifier<String>('');

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final root = await getRootDirectory();
    _notifyRootPathChanged(root.path);
  }

  Future<String> getRootPath() async {
    final directory = await getRootDirectory();
    return directory.path;
  }

  Future<Directory> getRootDirectory() async {
    _prefs ??= await SharedPreferences.getInstance();
    final customPath = _prefs!.getString(_customRootPathKey);
    if (customPath != null && customPath.trim().isNotEmpty) {
      final dir = Directory(customPath.trim());
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _notifyRootPathChanged(dir.path);
      return dir;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final defaultDir = Directory('${docsDir.path}/$_defaultFolderName');
    if (!await defaultDir.exists()) {
      await defaultDir.create(recursive: true);
    }
    _notifyRootPathChanged(defaultDir.path);
    return defaultDir;
  }

  Future<void> setRootPath(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Download root path cannot be empty.');
    }
    final dir = Directory(normalized);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_customRootPathKey, dir.path);
    _notifyRootPathChanged(dir.path);
  }

  Future<void> resetToDefaultRootPath() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_customRootPathKey);
    final root = await getRootDirectory();
    _notifyRootPathChanged(root.path);
  }

  Future<Directory> ensureSubDirectory(String folderName) async {
    final root = await getRootDirectory();
    final cleaned = folderName.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (cleaned.isEmpty) {
      return root;
    }
    final dir = Directory('${root.path}/$cleaned');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 将相对下载根目录的子路径（与 [ensureSubDirectory] 相同规则）解析为当前环境下的绝对路径。
  Future<String> absolutePathForRootRelativeSubfolder(String relativeToRoot) async {
    final Directory dir = await ensureSubDirectory(relativeToRoot);
    return dir.path;
  }

  /// 套图目录相对于 [getApplicationDocumentsDirectory] 的路径（`path` 包格式）。
  ///
  /// 用于持久化：iOS/Android 等沙盒根会变，但文档目录由 [path_provider] 每次解析到当前容器内路径。
  Future<String> relativePathFromApplicationDocumentsToSetFolder(
    String subFolderRelativeToDownloadRoot,
  ) async {
    final Directory setDir =
        await ensureSubDirectory(subFolderRelativeToDownloadRoot);
    final Directory docsDir = await getApplicationDocumentsDirectory();
    return p.relative(setDir.path, from: docsDir.path);
  }

  /// 将 [relativePathFromApplicationDocuments] 拼成当前会话下的绝对路径。
  Future<String> absolutePathFromApplicationDocumentsRelative(
    String relativePathFromApplicationDocuments,
  ) async {
    final Directory docsDir = await getApplicationDocumentsDirectory();
    return p.normalize(
      p.join(docsDir.path, relativePathFromApplicationDocuments),
    );
  }

  Future<File> prepareDownloadFile({
    required String fileName,
    String? subFolder,
  }) async {
    final safeFileName = fileName.trim();
    if (safeFileName.isEmpty) {
      throw ArgumentError('Download file name cannot be empty.');
    }
    final parent = subFolder == null || subFolder.trim().isEmpty
        ? await getRootDirectory()
        : await ensureSubDirectory(subFolder);
    return File('${parent.path}/$safeFileName');
  }

  void _notifyRootPathChanged(String path) {
    if (rootPathNotifier.value == path) return;
    rootPathNotifier.value = path;
  }
}
