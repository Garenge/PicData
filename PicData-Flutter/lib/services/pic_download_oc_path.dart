import 'dart:io';

import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';

/// 与 OC [PicBaseModel setTitle:] 一致：`systemTitle` = 展示标题中 `/` 替换为 `:`。
///
/// （PDDownloadManager `getDirPathWithSource:contentModel:` 使用 `sourceModel.systemTitle`、
/// `contentModel.systemTitle` 作为两级目录。）
String ocSystemTitleFromDisplayTitle(String title) {
  return title.replaceAll('/', ':');
}

/// 下载根目录下的相对路径：`{服务器名}/{套图名}`（与 OC 两级目录一致，不含「根路径」）。
String ocDownloadSubFolderPath({
  required PicHost? host,
  required PicContent content,
}) {
  final server = _ocServerFolderSegment(host);
  final set = _ocSetFolderSegment(content);
  return '$server/$set';
}

String _ocServerFolderSegment(PicHost? host) {
  final raw = _hostDisplayName(host);
  final system = ocSystemTitleFromDisplayTitle(raw);
  return _sanitizeFolderSegmentForFilesystem(system);
}

String _hostDisplayName(PicHost? host) {
  if (host == null) {
    return 'unknown_source';
  }
  final t = host.title.trim();
  if (t.isNotEmpty) {
    return t;
  }
  final m = host.mark?.trim() ?? '';
  if (m.isNotEmpty) {
    return m;
  }
  final u = host.hostUrl?.trim() ?? '';
  if (u.isNotEmpty) {
    return u;
  }
  return 'unknown_source';
}

String _ocSetFolderSegment(PicContent content) {
  var raw = content.title.trim();
  if (raw.isEmpty) {
    raw =
        'set_${content.href.hashCode.toUnsigned(32).toRadixString(16)}';
  }
  final system = ocSystemTitleFromDisplayTitle(raw);
  return _sanitizeFolderSegmentForFilesystem(system);
}

/// OC 仅做斜杠替换；各系统非法路径字符用下划线替代。
/// - **macOS**：`:` 来自「`/`→`:`」策略，保留以与 OC / Finder 行为一致。
/// - **Windows**：`:` 等为非法路径字符，需改为全角分号等替代，否则会创建目录失败。
String _sanitizeFolderSegmentForFilesystem(String segment) {
  var s = segment.trim();
  if (s.isEmpty) {
    return 'untitled';
  }
  if (s.length > 180) {
    s = s.substring(0, 180);
  }
  if (Platform.isWindows) {
    s = s.replaceAll(RegExp(r'[\\/*?"<>|]'), '_');
    s = s.replaceAll(':', '；');
  } else {
    s = s.replaceAll(RegExp(r'[\x00\r\n]'), '_');
  }
  if (s == '.' || s == '..') {
    return 'untitled';
  }
  return s;
}

/// 与 OC `downWithSource:...` 中 `url.lastPathComponent` 一致：取 URL 路径最后一段
///（有 `suggestNames` 时 OC 会覆盖；Flutter 侧暂无 suggest 列表，仅用 URL）。
String ocImageFileNameFromImageUrl(String urlString) {
  final uri = Uri.tryParse(urlString);
  if (uri == null) {
    return 'image_${urlString.hashCode.toUnsigned(32).toRadixString(16)}.bin';
  }

  final nonEmpty = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (nonEmpty.isEmpty) {
    return 'image_${urlString.hashCode.toUnsigned(32).toRadixString(16)}.bin';
  }

  var name = Uri.decodeComponent(nonEmpty.last);
  name = name.replaceAll(RegExp(r'[\\/]'), '_');
  if (name.isEmpty || name == '.' || name == '..') {
    return 'image_${urlString.hashCode.toUnsigned(32).toRadixString(16)}.bin';
  }

  if (Platform.isWindows) {
    name = name.replaceAll(RegExp(r'[:*?"<>|]'), '_');
  }

  return name;
}
