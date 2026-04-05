import 'dart:io';

/// 文件浏览器条目的粗粒度类型（文件夹 / 图片 / 文档）。
enum FileBrowserEntryKind {
  folder,
  image,
  document,
}

const _imageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'tif',
  'tiff',
  'ico',
  'avif',
};

const _documentExtensions = <String>{
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'txt',
  'md',
  'rtf',
  'csv',
  'json',
  'xml',
  'html',
  'htm',
  'pages',
  'numbers',
  'key',
};

String _extensionLower(String path) {
  final i = path.lastIndexOf('.');
  if (i <= 0 || i >= path.length - 1) {
    return '';
  }
  return path.substring(i + 1).toLowerCase();
}

/// 根据 [FileSystemEntity] 路径扩展名与类型划分条目种类。
///
/// 未识别的扩展名按「文档」处理（与通用文件图标一致）。
FileBrowserEntryKind classifyFileBrowserEntry(FileSystemEntity entity) {
  if (entity is Directory) {
    return FileBrowserEntryKind.folder;
  }
  if (entity is! File) {
    return FileBrowserEntryKind.document;
  }
  final ext = _extensionLower(entity.path);
  if (_imageExtensions.contains(ext)) {
    return FileBrowserEntryKind.image;
  }
  if (_documentExtensions.contains(ext)) {
    return FileBrowserEntryKind.document;
  }
  return FileBrowserEntryKind.document;
}
