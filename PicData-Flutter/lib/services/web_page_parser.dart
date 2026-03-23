import 'package:html/parser.dart' as html_parser;

import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/models/pic_content.dart';

/// 网页内容解析工具类。
///
/// - `extractReadableText`：保留之前的“简单提取纯文本”能力。
/// - `tryParseContentListToDebugText`：根据传入的 `PicHost.sourceType`
///   使用类似 OC 端的规则，尝试从 HTML 中解析「套图列表」，目前优先支持
///   `sourceType = 3`（hitxhot），解析结果以调试文本的形式返回。
class WebPageParser {
  const WebPageParser();

  String extractReadableText(String html) {
    if (html.isEmpty) return '';

    final withoutScript = html.replaceAll(
      RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
      '',
    );
    final withoutStyle = withoutScript.replaceAll(
      RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
      '',
    );

    final withoutTags = withoutStyle.replaceAll(RegExp(r'<[^>]+>'), ' ');

    final normalized = withoutTags.replaceAll(RegExp(r'\s+'), ' ');

    return normalized.trim();
  }

  /// 尝试按当前站点解析「套图列表」HTML，并以可读的调试文本返回。
  ///
  /// - 若传入的 `host` 为空或未识别的 `sourceType`，则回退到 `extractReadableText`。
  /// - 当前优先实现 `sourceType = 3`（对应 hitxhot），后续可按需扩展 4 / 5 / 10。
  String tryParseContentListToDebugText({
    required String html,
    required PicHost? host,
    String? entryUrl,
  }) {
    if (html.isEmpty) return 'HTML 为空，无法解析';

    final sourceType = host?.sourceType;
    if (sourceType == null) {
      return '当前站点未配置 sourceType，无法选择解析规则。\n'
          '可从原始 HTML 中提取纯文本作为回退：\n\n${extractReadableText(html)}';
    }

    switch (sourceType) {
      case 3:
        return _parseSourceType3List(html, host, entryUrl);
      case 4:
        return _parseSourceType4List(html, host, entryUrl);
      case 5:
        return _parseSourceType5List(html, host, entryUrl);
      case 10:
        return _parseSourceType10List(html, host, entryUrl);
      default:
        return '尚未为 sourceType=$sourceType 实现套图列表解析规则。\n'
            '暂时展示简化的纯文本内容，后续可按 OC 规则补齐：\n\n'
            '${extractReadableText(html)}';
    }
  }

  /// 返回结构化的套图列表数据源，供 UI 使用。
  ///
  /// 若解析失败则返回空列表。
  List<PicContent> parseContentList({
    required String html,
    required PicHost? host,
    String? entryUrl,
  }) {
    if (html.isEmpty) return <PicContent>[];

    final sourceType = host?.sourceType;
    if (sourceType == null) return <PicContent>[];

    switch (sourceType) {
      case 3:
        return _parseSourceType3Models(html, host);
      case 4:
        return _parseSourceType4Models(html, host);
      case 5:
        return _parseSourceType5Models(html, host);
      case 10:
        return _parseSourceType10Models(html, host);
      default:
        return <PicContent>[];
    }
  }

  /// 解析当前列表页的“下一页”链接。
  ///
  /// 返回补全为绝对地址后的 URL；若未找到则返回 null。
  String? parseNextPageUrl({
    required String html,
    required PicHost? host,
    String? entryUrl,
  }) {
    if (html.isEmpty) return null;

    final sourceType = host?.sourceType;
    if (sourceType == null) return null;

    print(
      'WebPageParser: parseNextPageUrl entryUrl="${entryUrl ?? ''}" sourceType=$sourceType',
    );

    switch (sourceType) {
      case 3:
        return _parseSourceType3NextPage(html, host);
      case 4:
        return _parseSourceType4NextPage(html, host);
      case 5:
        return _parseSourceType5NextPage(html, host);
      case 10:
        return _parseSourceType10NextPage(html, host);
      default:
        return null;
    }
  }

  /// 解析详情页当前页的所有图片 URL。
  ///
  /// 返回补全为绝对地址后的图片链接数组。
  List<String> parseDetailImages({
    required String html,
    required PicHost? host,
    String? detailUrl,
  }) {
    if (html.isEmpty) return <String>[];

    final sourceType = host?.sourceType;
    if (sourceType == null) return <String>[];

    switch (sourceType) {
      case 3:
        return _parseSourceType3DetailImages(html, host);
      case 4:
        return _parseSourceType4DetailImages(html, host);
      case 5:
        return _parseSourceType5DetailImages(html, host);
      case 10:
        return _parseSourceType10DetailImages(html, host);
      default:
        return <String>[];
    }
  }

  /// 解析详情页当前页的推荐套图列表。
  ///
  /// 返回结构化的 `PicContent` 数组；若站点暂不支持推荐，则返回空数组。
  List<PicContent> parseDetailSuggestions({
    required String html,
    required PicHost? host,
    String? detailUrl,
  }) {
    if (html.isEmpty) return <PicContent>[];

    final sourceType = host?.sourceType;
    if (sourceType == null) return <PicContent>[];

    switch (sourceType) {
      case 3:
        // 与 OC 端同步：同步解析阶段不返回推荐，后续可按需实现异步推荐逻辑。
        return <PicContent>[];
      case 4:
        return _parseSourceType4SuggestionModels(html, host);
      case 5:
        return _parseSourceType5SuggestionModels(html, host);
      case 10:
        // SourceType10 详情页推荐与列表布局相同，可复用列表解析逻辑。
        return _parseSourceType10Models(html, host);
      default:
        return <PicContent>[];
    }
  }

  /// 解析套图详情页的“下一页”链接。
  ///
  /// 说明：
  /// - 不改变原有列表分页能力，只补充详情页 next 的少量站点差异。
  /// - 返回补全为绝对 URL；若未找到则返回 null。
  String? parseDetailNextPageUrl({
    required String html,
    required PicHost? host,
    String? detailUrl,
  }) {
    if (html.isEmpty) return null;

    final sourceType = host?.sourceType;
    if (sourceType == null) return null;

    print(
      'WebPageParser: parseDetailNextPageUrl detailUrl="${detailUrl ?? ''}" '
      'sourceType=$sourceType hostHostUrl="${host?.hostUrl ?? ''}"',
    );

    switch (sourceType) {
      case 3:
        final next = _parseSourceType3DetailNextPage(html, host);
        print('WebPageParser: sourceType=3 detail nextHref="${next ?? ''}"');
        return next;
      default:
        // 大部分站点可以复用“列表页 next”解析策略。
        final next = parseNextPageUrl(
          html: html,
          host: host,
          entryUrl: detailUrl,
        );
        print(
          'WebPageParser: sourceType=$sourceType fallback nextHref="${next ?? ''}"',
        );
        return next;
    }
  }

  /// `sourceType = 3`（hitxhot）详情页 next 解析。
  ///
  /// notes 中的 OC 规则：详情下一页依据 `<a>` 的文字（如 “Next >”）。
  /// Flutter 端先做保守匹配：在 `.nav-links` 下寻找包含 “Next” 的链接。
  String? _parseSourceType3DetailNextPage(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final nextContainer = document.querySelector('.nav-links');
    if (nextContainer == null) return null;

    final allLinks = nextContainer.querySelectorAll('a');
    print(
      'WebPageParser: sourceType=3 detail next selector ".nav-links" found, '
      'aCount=${allLinks.length}',
    );

    var matched = 0;
    for (final link in nextContainer.querySelectorAll('a')) {
      final text = link.text.trim();
      if (text.contains('Next')) {
        matched++;
        final href = link.attributes['href']?.trim() ?? '';
        final resolved = _resolveUrl(href, host);
        print(
          'WebPageParser: sourceType=3 detail next match text="$text" '
          'rawHref="$href" resolvedHref="$resolved"',
        );
        if (resolved.isNotEmpty) return resolved;
      }
    }

    print(
      'WebPageParser: sourceType=3 detail next matches=$matched but '
      'all resolved hrefs were empty',
    );
    return null;
  }

  /// 尝试基于站点配置把相对地址补全为绝对 URL。
  ///
  /// - 若 `raw` 为空，则返回空字符串；
  /// - 若已是绝对地址（`http` / `https`），原样返回；
  /// - 否则基于 `host.hostUrl` 进行拼接，尽量还原 OC 中 `getThumbnailUrlFromImageElement`
  ///   对缩略图 / 链接的补全策略。
  String _resolveUrl(String? raw, PicHost? host) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final base = host?.hostUrl;
    if (base == null || base.isEmpty) {
      return value;
    }

    try {
      final baseUri = Uri.parse(base);
      final resolved = baseUri.resolve(value);
      return resolved.toString();
    } catch (_) {
      return value;
    }
  }

  /// `sourceType = 3` 详情页图片解析。
  ///
  /// - 图片容器：`.VKSUBTSWA`
  /// - 其中所有 `img` 的 `src` 作为图片地址。
  List<String> _parseSourceType3DetailImages(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final container = document.querySelector('.VKSUBTSWA');
    if (container == null) return <String>[];

    final results = <String>[];
    for (final img in container.querySelectorAll('img')) {
      final url = _resolveUrl(img.attributes['src']?.trim(), host);
      if (url.isNotEmpty) {
        results.add(url);
      }
    }
    return results;
  }

  /// `sourceType = 4` 详情页图片解析。
  ///
  /// - 图片容器：`.content`
  /// - 其中所有 `img` 的 `src` 作为图片地址。
  List<String> _parseSourceType4DetailImages(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final container = document.querySelector('.content');
    if (container == null) return <String>[];

    final results = <String>[];
    for (final img in container.querySelectorAll('img')) {
      final url = _resolveUrl(img.attributes['src']?.trim(), host);
      if (url.isNotEmpty) {
        results.add(url);
      }
    }
    return results;
  }

  /// `sourceType = 5` 详情页图片解析。
  ///
  /// - 图片容器：`.file-detail`
  /// - 其中所有 `img` 的 `src` 作为图片地址。
  List<String> _parseSourceType5DetailImages(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final container = document.querySelector('.file-detail');
    if (container == null) return <String>[];

    final results = <String>[];
    for (final img in container.querySelectorAll('img')) {
      final url = _resolveUrl(img.attributes['src']?.trim(), host);
      if (url.isNotEmpty) {
        results.add(url);
      }
    }
    return results;
  }

  /// `sourceType = 10` 详情页图片解析。
  ///
  /// - 图片容器：`.article-fulltext`
  /// - 其中所有 `img` 的 `src` 作为图片地址。
  List<String> _parseSourceType10DetailImages(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final container = document.querySelector('.article-fulltext');
    if (container == null) return <String>[];

    final results = <String>[];
    for (final img in container.querySelectorAll('img')) {
      final url = _resolveUrl(img.attributes['src']?.trim(), host);
      if (url.isNotEmpty) {
        results.add(url);
      }
    }
    return results;
  }

  /// `sourceType = 3`（hitxhot）列表页解析。
  ///
  /// 参考 `ParsingRules.md`：
  /// - 列表容器：`div.HCRIN`
  /// - 套图节点：`div.VVAHRQFF`
  /// - 每个节点：
  ///   - 主链接：第一个 `a` 标签的 `href`
  ///   - 封面图：第一个 `img`
  ///   - 标题：`div.GZDHFYIQ` 下第一个 `a` 的文本
  String _parseSourceType3List(String html, PicHost? host, String? entryUrl) {
    final document = html_parser.parse(html);

    final container = document.querySelector('div.HCRIN');
    if (container == null) {
      return '未找到列表容器 div.HCRIN，可能当前页面不是列表页或站点结构已变。\n'
          '入口 URL: ${entryUrl ?? '-'}';
    }

    final items = <String>[];

    for (final article in container.querySelectorAll('div.VVAHRQFF')) {
      final link = article.querySelector('a');
      final href = link?.attributes['href']?.trim() ?? '';

      final titleElement = article.querySelector('div.GZDHFYIQ a');
      final title = titleElement?.text.trim() ?? '';

      final img = article.querySelector('img');
      final thumb =
          img?.attributes['src']?.trim() ??
          img?.attributes['data-src']?.trim() ??
          '';

      if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
        continue;
      }

      final buffer = StringBuffer();
      buffer.writeln(title.isEmpty ? '(无标题)' : title);
      if (href.isNotEmpty) {
        buffer.writeln('  href : $href');
      }
      if (thumb.isNotEmpty) {
        buffer.writeln('  thumb: $thumb');
      }

      items.add(buffer.toString().trimRight());
    }

    if (items.isEmpty) {
      return '已找到列表容器 div.HCRIN，但未从其中解析出任何套图项。\n'
          '入口 URL: ${entryUrl ?? '-'}';
    }

    final sourceMark = host?.mark ?? host?.title ?? '';
    final header = StringBuffer()
      ..writeln(
        '按 sourceType=3 (hitxhot) 规则解析套图列表，'
        '共解析到 ${items.length} 个条目。',
      );
    if (sourceMark.isNotEmpty) {
      header.writeln('当前站点: $sourceMark');
    }
    if (entryUrl != null && entryUrl.isNotEmpty) {
      header.writeln('入口 URL: $entryUrl');
    }

    return '${header.toString().trimRight()}\n\n${items.join('\n\n')}';
  }

  /// `sourceType = 3` 对应的结构化列表解析。
  List<PicContent> _parseSourceType3Models(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final container = document.querySelector('div.HCRIN');
    if (container == null) return <PicContent>[];

    final results = <PicContent>[];
    for (final article in container.querySelectorAll('div.VVAHRQFF')) {
      final link = article.querySelector('a');
      final href = _resolveUrl(link?.attributes['href']?.trim(), host);

      final titleElement = article.querySelector('div.GZDHFYIQ a');
      final title = titleElement?.text.trim() ?? '';

      final img = article.querySelector('img');
      final thumb = _resolveUrl(
        img?.attributes['src']?.trim() ?? img?.attributes['data-src']?.trim(),
        host,
      );

      if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
        continue;
      }

      results.add(
        PicContent(
          title: title.isEmpty ? '(无标题)' : title,
          href: href,
          thumbnail: thumb,
        ),
      );
    }
    return results;
  }

  /// `sourceType = 4`（meirentu）列表页解析。
  ///
  /// - 列表容器：`div.update_area_content`
  /// - 套图项：`.i_list`
  /// - 每个套图：
  ///   - 主链接：`articleElement` 下第一个 `a` 的 `href`
  ///   - 封面图：这个 `a` 内的第一个 `img`
  ///   - 标题：`.meta-title` 元素的文本
  String _parseSourceType4List(String html, PicHost? host, String? entryUrl) {
    final document = html_parser.parse(html);
    final container = document.querySelector('div.update_area_content');
    if (container == null) {
      return '未找到列表容器 div.update_area_content，可能当前页面不是列表页或站点结构已变。\n'
          '入口 URL: ${entryUrl ?? '-'}';
    }

    final items = <String>[];

    for (final article in container.querySelectorAll('.i_list')) {
      final link = article.querySelector('a');
      final href = link?.attributes['href']?.trim() ?? '';

      final img = link?.querySelector('img') ?? article.querySelector('img');
      final thumb =
          img?.attributes['src']?.trim() ??
          img?.attributes['data-src']?.trim() ??
          '';

      final titleElement = article.querySelector('.meta-title');
      final title = titleElement?.text.trim() ?? '';

      if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
        continue;
      }

      final buffer = StringBuffer();
      buffer.writeln(title.isEmpty ? '(无标题)' : title);
      if (href.isNotEmpty) {
        buffer.writeln('  href : $href');
      }
      if (thumb.isNotEmpty) {
        buffer.writeln('  thumb: $thumb');
      }

      items.add(buffer.toString().trimRight());
    }

    if (items.isEmpty) {
      return '已找到列表容器 div.update_area_content，但未从其中解析出任何套图项。\n'
          '入口 URL: ${entryUrl ?? '-'}';
    }

    final sourceMark = host?.mark ?? host?.title ?? '';
    final header = StringBuffer()
      ..writeln(
        '按 sourceType=4 (meirentu) 规则解析套图列表，'
        '共解析到 ${items.length} 个条目。',
      );
    if (sourceMark.isNotEmpty) {
      header.writeln('当前站点: $sourceMark');
    }
    if (entryUrl != null && entryUrl.isNotEmpty) {
      header.writeln('入口 URL: $entryUrl');
    }

    return '${header.toString().trimRight()}\n\n${items.join('\n\n')}';
  }

  /// `sourceType = 4` 对应的结构化列表解析。
  List<PicContent> _parseSourceType4Models(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final container = document.querySelector('div.update_area_content');
    if (container == null) return <PicContent>[];

    final results = <PicContent>[];
    for (final article in container.querySelectorAll('.i_list')) {
      final link = article.querySelector('a');
      final href = _resolveUrl(link?.attributes['href']?.trim(), host);

      final img = link?.querySelector('img') ?? article.querySelector('img');
      final thumb = _resolveUrl(
        img?.attributes['src']?.trim() ?? img?.attributes['data-src']?.trim(),
        host,
      );

      final titleElement = article.querySelector('.meta-title');
      final title = titleElement?.text.trim() ?? '';

      if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
        continue;
      }

      results.add(
        PicContent(
          title: title.isEmpty ? '(无标题)' : title,
          href: href,
          thumbnail: thumb,
        ),
      );
    }
    return results;
  }

  /// `sourceType = 4` 详情页推荐套图解析。
  ///
  /// - 推荐容器：`div.update_area_lists`
  /// - 套图项：`.i_list`，结构与列表页相同。
  List<PicContent> _parseSourceType4SuggestionModels(
    String html,
    PicHost? host,
  ) {
    final document = html_parser.parse(html);
    final container = document.querySelector('div.update_area_lists');
    if (container == null) return <PicContent>[];

    final results = <PicContent>[];
    for (final article in container.querySelectorAll('.i_list')) {
      final link = article.querySelector('a');
      final href = _resolveUrl(link?.attributes['href']?.trim(), host);

      final img = link?.querySelector('img') ?? article.querySelector('img');
      final thumb = _resolveUrl(
        img?.attributes['src']?.trim() ?? img?.attributes['data-src']?.trim(),
        host,
      );

      final titleElement = article.querySelector('.meta-title');
      final title = titleElement?.text.trim() ?? '';

      if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
        continue;
      }

      results.add(
        PicContent(
          title: title.isEmpty ? '(无标题)' : title,
          href: href,
          thumbnail: thumb,
        ),
      );
    }
    return results;
  }

  /// `sourceType = 5`（tuzac）列表页解析。
  ///
  /// - 列表容器：`.content`
  /// - 套图项：`.clearfix`
  /// - 每个套图：
  ///   - 主链接：第一个 `a` 的 `href`
  ///   - 封面图：第一个 `img`
  ///   - 标题：`img` 的 `title` 属性，并追加基于 href 提取的 ID
  String _parseSourceType5List(String html, PicHost? host, String? entryUrl) {
    final document = html_parser.parse(html);
    final container = document.querySelector('.content');
    if (container == null) {
      return '未找到列表容器 .content，可能当前页面不是列表页或站点结构已变。\n'
          '入口 URL: ${entryUrl ?? '-'}';
    }

    final items = <String>[];

    for (final article in container.querySelectorAll('.clearfix')) {
      final link = article.querySelector('a');
      final href = link?.attributes['href']?.trim() ?? '';

      final img = article.querySelector('img');
      final thumb =
          img?.attributes['src']?.trim() ??
          img?.attributes['data-src']?.trim() ??
          '';

      final rawTitle = img?.attributes['title']?.trim() ?? '';
      var title = rawTitle;

      // 模拟 OC 中的 updateCustomContentName 逻辑：
      // 若标题非空，则从 contentHref 提取最后一段路径（去掉扩展名）作为 ID，并拼接。
      if (title.isNotEmpty && href.isNotEmpty) {
        final uri = Uri.tryParse(href);
        final lastSegment = uri?.pathSegments.isNotEmpty == true
            ? uri!.pathSegments.last
            : '';
        var id = lastSegment;
        final dotIndex = id.lastIndexOf('.');
        if (dotIndex > 0) {
          id = id.substring(0, dotIndex);
        }
        if (id.isNotEmpty) {
          title = '$title $id';
        }
      }

      if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
        continue;
      }

      final buffer = StringBuffer();
      buffer.writeln(title.isEmpty ? '(无标题)' : title);
      if (href.isNotEmpty) {
        buffer.writeln('  href : $href');
      }
      if (thumb.isNotEmpty) {
        buffer.writeln('  thumb: $thumb');
      }

      items.add(buffer.toString().trimRight());
    }

    if (items.isEmpty) {
      return '已找到列表容器 .content，但未从其中解析出任何套图项。\n'
          '入口 URL: ${entryUrl ?? '-'}';
    }

    final sourceMark = host?.mark ?? host?.title ?? '';
    final header = StringBuffer()
      ..writeln(
        '按 sourceType=5 (tuzac) 规则解析套图列表，'
        '共解析到 ${items.length} 个条目。',
      );
    if (sourceMark.isNotEmpty) {
      header.writeln('当前站点: $sourceMark');
    }
    if (entryUrl != null && entryUrl.isNotEmpty) {
      header.writeln('入口 URL: $entryUrl');
    }

    return '${header.toString().trimRight()}\n\n${items.join('\n\n')}';
  }

  /// `sourceType = 5` 对应的结构化列表解析。
  List<PicContent> _parseSourceType5Models(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final container = document.querySelector('.content');
    if (container == null) return <PicContent>[];

    final results = <PicContent>[];
    for (final article in container.querySelectorAll('.clearfix')) {
      final link = article.querySelector('a');
      final href = _resolveUrl(link?.attributes['href']?.trim(), host);

      final img = article.querySelector('img');
      final thumb = _resolveUrl(
        img?.attributes['src']?.trim() ?? img?.attributes['data-src']?.trim(),
        host,
      );

      final rawTitle = img?.attributes['title']?.trim() ?? '';
      var title = rawTitle;

      if (title.isNotEmpty && href.isNotEmpty) {
        final uri = Uri.tryParse(href);
        final lastSegment = uri?.pathSegments.isNotEmpty == true
            ? uri!.pathSegments.last
            : '';
        var id = lastSegment;
        final dotIndex = id.lastIndexOf('.');
        if (dotIndex > 0) {
          id = id.substring(0, dotIndex);
        }
        if (id.isNotEmpty) {
          title = '$title $id';
        }
      }

      if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
        continue;
      }

      results.add(
        PicContent(
          title: title.isEmpty ? '(无标题)' : title,
          href: href,
          thumbnail: thumb,
        ),
      );
    }
    return results;
  }

  /// `sourceType = 5` 详情页推荐套图解析。
  ///
  /// - 推荐容器：`.related-files`
  /// - 套图项：`.clearfix`，结构与列表页相同。
  List<PicContent> _parseSourceType5SuggestionModels(
    String html,
    PicHost? host,
  ) {
    final document = html_parser.parse(html);
    final container = document.querySelector('.related-files');
    if (container == null) return <PicContent>[];

    final results = <PicContent>[];
    for (final article in container.querySelectorAll('.clearfix')) {
      final link = article.querySelector('a');
      final href = _resolveUrl(link?.attributes['href']?.trim(), host);

      final img = article.querySelector('img');
      final thumb = _resolveUrl(
        img?.attributes['src']?.trim() ?? img?.attributes['data-src']?.trim(),
        host,
      );

      final rawTitle = img?.attributes['title']?.trim() ?? '';
      var title = rawTitle;

      if (title.isNotEmpty && href.isNotEmpty) {
        final uri = Uri.tryParse(href);
        final lastSegment = uri?.pathSegments.isNotEmpty == true
            ? uri!.pathSegments.last
            : '';
        var id = lastSegment;
        final dotIndex = id.lastIndexOf('.');
        if (dotIndex > 0) {
          id = id.substring(0, dotIndex);
        }
        if (id.isNotEmpty) {
          title = '$title $id';
        }
      }

      if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
        continue;
      }

      results.add(
        PicContent(
          title: title.isEmpty ? '(无标题)' : title,
          href: href,
          thumbnail: thumb,
        ),
      );
    }
    return results;
  }

  /// `sourceType = 10`（buondua）列表页解析。
  ///
  /// - 整体容器：`.blog`
  /// - 在 `.blog` 下收集 `.items-row`
  /// - 每个套图：
  ///   - 主链接：第一个 `a` 的 `href`
  ///   - 封面图：该 `a` 内的第一个 `img`
  ///   - 标题：`img` 的 `alt` 属性，去掉 `()` 内内容后追加 identifier
  String _parseSourceType10List(String html, PicHost? host, String? entryUrl) {
    final document = html_parser.parse(html);
    final blogContainers = document.querySelectorAll('.blog');
    if (blogContainers.isEmpty) {
      return '未找到列表容器 .blog，可能当前页面不是列表页或站点结构已变。\n'
          '入口 URL: ${entryUrl ?? '-'}';
    }

    final items = <String>[];

    for (final blog in blogContainers) {
      for (final row in blog.querySelectorAll('.items-row')) {
        final link = row.querySelector('a');
        final href = link?.attributes['href']?.trim() ?? '';

        final img = link?.querySelector('img') ?? row.querySelector('img');
        final rawTitle = img?.attributes['alt']?.trim() ?? '';
        final thumb =
            img?.attributes['src']?.trim() ??
            img?.attributes['data-src']?.trim() ??
            '';

        // updateCustomContentName:
        // - 去掉圆括号 () 内的子串
        // - 去除首尾空格
        // - 从 href 中使用 ".com-" 到 ".webp?" 之间的子串作为 identifier
        var title = rawTitle;
        if (title.isNotEmpty) {
          title = title.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
        }

        if (title.isNotEmpty && href.isNotEmpty) {
          final start = href.indexOf('.com-');
          final end = href.indexOf('.webp?');
          if (start >= 0 && end > start + 5) {
            final identifier = href.substring(start + 5, end);
            if (identifier.isNotEmpty) {
              title = '$title $identifier';
            }
          }
        }

        if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
          continue;
        }

        final buffer = StringBuffer();
        buffer.writeln(title.isEmpty ? '(无标题)' : title);
        if (href.isNotEmpty) {
          buffer.writeln('  href : $href');
        }
        if (thumb.isNotEmpty) {
          buffer.writeln('  thumb: $thumb');
        }

        items.add(buffer.toString().trimRight());
      }
    }

    if (items.isEmpty) {
      return '已找到 .blog 容器，但未从其中解析出任何套图项。\n'
          '入口 URL: ${entryUrl ?? '-'}';
    }

    final sourceMark = host?.mark ?? host?.title ?? '';
    final header = StringBuffer()
      ..writeln(
        '按 sourceType=10 (buondua) 规则解析套图列表，'
        '共解析到 ${items.length} 个条目。',
      );
    if (sourceMark.isNotEmpty) {
      header.writeln('当前站点: $sourceMark');
    }
    if (entryUrl != null && entryUrl.isNotEmpty) {
      header.writeln('入口 URL: $entryUrl');
    }

    return '${header.toString().trimRight()}\n\n${items.join('\n\n')}';
  }

  /// `sourceType = 10` 对应的结构化列表解析。
  List<PicContent> _parseSourceType10Models(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final blogContainers = document.querySelectorAll('.blog');
    if (blogContainers.isEmpty) return <PicContent>[];

    final results = <PicContent>[];
    for (final blog in blogContainers) {
      for (final row in blog.querySelectorAll('.items-row')) {
        final link = row.querySelector('a');
        final href = _resolveUrl(link?.attributes['href']?.trim(), host);

        final img = link?.querySelector('img') ?? row.querySelector('img');
        final rawTitle = img?.attributes['alt']?.trim() ?? '';
        final thumb = _resolveUrl(
          img?.attributes['src']?.trim() ?? img?.attributes['data-src']?.trim(),
          host,
        );

        var title = rawTitle;
        if (title.isNotEmpty) {
          title = title.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
        }

        if (title.isNotEmpty && href.isNotEmpty) {
          final start = href.indexOf('.com-');
          final end = href.indexOf('.webp?');
          if (start >= 0 && end > start + 5) {
            final identifier = href.substring(start + 5, end);
            if (identifier.isNotEmpty) {
              title = '$title $identifier';
            }
          }
        }

        if (href.isEmpty && title.isEmpty && thumb.isEmpty) {
          continue;
        }

        results.add(
          PicContent(
            title: title.isEmpty ? '(无标题)' : title,
            href: href,
            thumbnail: thumb,
          ),
        );
      }
    }
    return results;
  }

  String? _parseSourceType3NextPage(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final nextContainer = document.querySelector('.nav-next');
    if (nextContainer == null) {
      print('WebPageParser: sourceType=3 next ".nav-next" not found');
      return null;
    }

    final links = nextContainer.querySelectorAll('a');
    print('WebPageParser: sourceType=3 next ".nav-next" aCount=${links.length}');
    for (final link in nextContainer.querySelectorAll('a')) {
      final text = link.text.trim();
      if (text == '→' || text.contains('→')) {
        final href = link.attributes['href']?.trim();
        final resolved = _resolveUrl(href, host);
        print(
          'WebPageParser: sourceType=3 next match text="$text" '
          'rawHref="${href ?? ''}" resolvedHref="$resolved"',
        );
        if (resolved.isNotEmpty) return resolved;
        break;
      }
    }
    return null;
  }

  String? _parseSourceType4NextPage(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final nextContainer = document.querySelector('.page');
    if (nextContainer == null) {
      print('WebPageParser: sourceType=4 next ".page" not found');
      return null;
    }

    for (final link in nextContainer.querySelectorAll('a')) {
      final text = link.text.trim();
      if (text == '下页') {
        final href = link.attributes['href']?.trim();
        final resolved = _resolveUrl(href, host);
        print(
          'WebPageParser: sourceType=4 next match text="$text" '
          'rawHref="$href" resolvedHref="$resolved"',
        );
        if (resolved.isNotEmpty) return resolved;
        break;
      }
    }
    return null;
  }

  String? _parseSourceType5NextPage(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final nextContainer = document.querySelector('#pager');
    if (nextContainer == null) {
      print('WebPageParser: sourceType=5 next "#pager" not found');
      return null;
    }

    for (final link in nextContainer.querySelectorAll('a')) {
      final text = link.text.trim();
      const nextPageTitle = '下一页 ›';
      if (text == nextPageTitle || text.contains(nextPageTitle)) {
        final href = link.attributes['href']?.trim();
        final resolved = _resolveUrl(href, host);
        print(
          'WebPageParser: sourceType=5 next match text="$text" '
          'rawHref="$href" resolvedHref="$resolved"',
        );
        if (resolved.isNotEmpty) return resolved;
        break;
      }
    }
    return null;
  }

  String? _parseSourceType10NextPage(String html, PicHost? host) {
    final document = html_parser.parse(html);
    final nextContainer = document.querySelector('.pagination-list');
    if (nextContainer == null) {
      print('WebPageParser: sourceType=10 next ".pagination-list" not found');
      return null;
    }

    final links = nextContainer.querySelectorAll('a');
    if (links.isEmpty) {
      print('WebPageParser: sourceType=10 next ".pagination-list" a empty');
      return null;
    }
    print('WebPageParser: sourceType=10 next aCount=${links.length}');

    // 先按“当前页标识”找后继链接（和列表分页保持一致的常见实现）。
    //
    // 现实中站点会有多种激活 class 命名，这里做兼容。
    const activeClassTokens = <String>[
      'is-current',
      'is-active',
      'active',
      'current',
    ];

    var currentIndex = -1;
    for (var i = 0; i < links.length; i++) {
      final classes = links[i].attributes['class'] ?? '';
      if (activeClassTokens.any((t) => classes.contains(t))) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex >= 0 && currentIndex < links.length - 1) {
      final nextLink = links[currentIndex + 1];
      final href = nextLink.attributes['href']?.trim();
      final resolved = _resolveUrl(href, host);
      print(
        'WebPageParser: sourceType=10 next activeIndex=$currentIndex '
        'nextRawHref="$href" resolvedHref="$resolved"',
      );
      if (resolved.isNotEmpty) return resolved;
    }

    // 再做文本/符号兜底匹配：有些详情页 next 不一定带“is-current”，
    // 但 next 按钮一般具有明确的文案（下一页 / Next / 下一頁 / →）。
    final keywords = <String>[
      '下一页',
      '下一頁',
      'Next',
      'next',
      '→',
      '下页',
    ];

    for (final link in links) {
      final text = link.text.trim();
      if (text.isEmpty) continue;
      if (!keywords.any((k) => text.contains(k))) continue;

      final href = link.attributes['href']?.trim() ?? '';
      final resolved = _resolveUrl(href, host);
      print(
        'WebPageParser: sourceType=10 next keyword match text="$text" '
        'rawHref="$href" resolvedHref="$resolved"',
      );
      if (resolved.isNotEmpty) return resolved;
    }

    return null;
  }
}
