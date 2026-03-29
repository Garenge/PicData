import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/services/pic_detail_page_loader.dart';

/// 套图分页解析（与详情页同一 [PicDetailPageLoader] / 解析规则）。
///
/// 供「仅日志收集」与 [PicDownloadModule] 的队列下载共用。
class PicSetDownloadManager {
  PicSetDownloadManager({PicDetailPageLoader? loader})
      : _loader = loader ?? PicDetailPageLoader();

  final PicDetailPageLoader _loader;

  static const String _header = '========== PicSetDownload · 收集套图 URL ==========';

  static void _out(String line) {
    // ignore: avoid_print
    print(line);
  }

  /// 从 [content.href] 起顺链抓取每页详情，并对每页调用 [onPage]（便于边解析边消费 URL）。
  Future<void> walkPagesForSet({
    required PicContent content,
    required PicHost? host,
    required Future<void> Function(PicDetailLoadedPage page) onPage,
    bool logPages = false,
  }) async {
    final visited = <String>{};
    String? href = content.href;
    var pageIndex = 0;

    if (logPages) {
      _out('');
      _out(_header);
      _out('标题  │ ${content.title}');
      _out('起点  │ $href');
      _out('-- 分页 --');
    }

    while (href != null && href.isNotEmpty) {
      if (visited.contains(href)) {
        if (logPages) {
          _out(
            'PicData-Flutter/lib/services/pic_set_download_manager.dart '
            '#walkPagesForSet: 检测到循环，停止于 » $href',
          );
        }
        break;
      }
      visited.add(href);
      pageIndex++;

      final page = await _loader.loadPage(
        href: href,
        host: host,
        compactDiagnostics: true,
      );

      if (logPages) {
        final hasNext = page.nextHref != null && page.nextHref!.isNotEmpty;
        _out(
          '  #$pageIndex  本页图片 ${page.imageUrls.length} 张'
          '  · 下一页 ${hasNext ? "有" : "无"}',
        );
      }

      await onPage(page);
      href = page.nextHref;
    }

    if (logPages) {
      _out('========== PicSetDownload · walk 结束 ==========');
      _out('');
    }
  }

  /// 从 [content.href] 起，沿详情「下一页」链抓取每一页，合并所有图片 URL。
  ///
  /// 返回合并后的列表，并在控制台以分块、逐条 URL 形式打印（调试用）。
  Future<List<String>> collectAllImageUrlsForSet({
    required PicContent content,
    PicHost? host,
  }) async {
    final all = <String>[];
    await walkPagesForSet(
      content: content,
      host: host,
      logPages: true,
      onPage: (page) async {
        all.addAll(page.imageUrls);
      },
    );

    _out('-- 汇总 --');
    _out('共 ${all.length} 张');
    _out('-- image URLs（逐行）--');
    for (var i = 0; i < all.length; i++) {
      final idx = (i + 1).toString().padLeft(3);
      _out('  [$idx] ${all[i]}');
    }
    _out('========== PicSetDownload · 结束 ==========');
    _out('');

    return all;
  }
}
