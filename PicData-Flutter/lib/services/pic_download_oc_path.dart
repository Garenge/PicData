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
  final m = host.mark?.trim() ?? '';
  if (m.isNotEmpty) {
    return m;
  }
  final fromTitle = _hostFolderNameDerivedFromTitle(host.title);
  if (fromTitle != null && fromTitle.isNotEmpty) {
    return fromTitle;
  }
  final fromUrl = _hostFolderNameDerivedFromTitle(host.hostUrl ?? '');
  if (fromUrl != null && fromUrl.isNotEmpty) {
    return fromUrl;
  }
  return 'unknown_source';
}

/// `mark` 为空时：从标题/URL 抽出「站点名」作目录段——去掉协议、路径、`www.`，
/// 再按标签取核心名；非 URL 标题则将 `.` 换成 `_`。
String? _hostFolderNameDerivedFromTitle(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = _tryParseLooseHttpUrl(trimmed);
  if (uri != null && uri.host.isNotEmpty) {
    final core = _coreSiteLabelFromHost(uri.host);
    if (core.isNotEmpty) {
      return core.replaceAll('.', '_');
    }
  }

  final plain = _plainTitleAsFolderSegment(trimmed);
  if (plain.isEmpty) {
    return null;
  }
  return plain;
}

/// 识别 `http(s)://...` 或无协议但形如 `host/path` 的字符串。
Uri? _tryParseLooseHttpUrl(String s) {
  var u = Uri.tryParse(s);
  if (u != null && u.hasScheme && u.host.isNotEmpty) {
    return u;
  }
  if (s.contains('://')) {
    return null;
  }
  if (!s.contains(' ') && s.contains('.')) {
    u = Uri.tryParse('https://$s');
    if (u != null && u.host.isNotEmpty) {
      return u;
    }
  }
  return null;
}

/// 从 hostname 取出「站点主名」：去掉 `www.`，再按二级/复合 TLD 取标签。
String _coreSiteLabelFromHost(String host) {
  var h = host.toLowerCase().trim();
  if (h.startsWith('www.')) {
    h = h.substring(4);
  }
  final parts = h.split('.').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '';
  }
  if (parts.length == 1) {
    return parts[0];
  }
  if (parts.length == 2) {
    return parts[0];
  }

  final join2 = '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
  if (_compoundTlds.contains(join2) && parts.length >= 3) {
    return parts[parts.length - 3];
  }

  return parts[parts.length - 2];
}

/// 常见复合顶级域（无 PSL 时的近似处理）。
const Set<String> _compoundTlds = {
  'co.uk',
  'co.jp',
  'co.nz',
  'co.kr',
  'com.au',
  'com.br',
  'com.cn',
  'com.hk',
  'com.sg',
  'com.tw',
  'net.cn',
  'org.uk',
  'ac.uk',
  'gov.uk',
};

String _plainTitleAsFolderSegment(String s) {
  var t = s.replaceAll('.', '_');
  t = t.replaceAll(RegExp(r'_+'), '_');
  return t.trim();
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

/// 按详情解析顺序保存时的本地文件名：`1.jpg`、`2.webp`…
///
/// 扩展名尽量与 [urlString] 路径最后一段一致；无法识别时用 `.jpg`。
String ocSequentialImageFileName(int sequence1Based, String urlString) {
  if (sequence1Based < 1) {
    throw ArgumentError.value(
      sequence1Based,
      'sequence1Based',
      'must be >= 1',
    );
  }
  final baseName = ocImageFileNameFromImageUrl(urlString);
  final dot = baseName.lastIndexOf('.');
  var ext = '.jpg';
  if (dot > 0 && dot < baseName.length - 1) {
    final raw = baseName.substring(dot).toLowerCase();
    if (raw.length <= 10 && RegExp(r'^\.[a-z0-9]+$').hasMatch(raw)) {
      ext = raw;
    }
  }
  return '$sequence1Based$ext';
}
