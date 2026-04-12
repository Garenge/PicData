import 'package:pic_data/models/pic_content.dart';

/// 按「下载记录里已完成」的 [PicContent.href] 设置 [PicContent.isDownloaded]。
///
/// [completedContentHrefs] 通常来自 [PicSetDownloadRecordStore.completedContentHrefSet]。
List<PicContent> applyCompletedDownloadFlagsToContents(
  List<PicContent> contents,
  Set<String> completedContentHrefs,
) {
  if (contents.isEmpty) {
    return contents;
  }
  return List<PicContent>.generate(contents.length, (int i) {
    final PicContent c = contents[i];
    final bool downloaded =
        c.href.isNotEmpty && completedContentHrefs.contains(c.href);
    final bool prev = c.isDownloaded ?? false;
    if (prev == downloaded) {
      return c;
    }
    return PicContent(
      title: c.title,
      href: c.href,
      thumbnail: c.thumbnail,
      isDownloaded: downloaded,
    );
  }, growable: false);
}
