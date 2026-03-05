import 'package:html/parser.dart' as html_parser;

import '../models/pic_net_models.dart';
import '../models/pic_content.dart';

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
        return _parseSourceType3Models(html);
      case 4:
        return _parseSourceType4Models(html);
      case 5:
        return _parseSourceType5Models(html);
      case 10:
        return _parseSourceType10Models(html);
      default:
        return <PicContent>[];
    }
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
  List<PicContent> _parseSourceType3Models(String html) {
    final document = html_parser.parse(html);
    final container = document.querySelector('div.HCRIN');
    if (container == null) return <PicContent>[];

    final results = <PicContent>[];
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
  List<PicContent> _parseSourceType4Models(String html) {
    final document = html_parser.parse(html);
    final container = document.querySelector('div.update_area_content');
    if (container == null) return <PicContent>[];

    final results = <PicContent>[];
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
  List<PicContent> _parseSourceType5Models(String html) {
    final document = html_parser.parse(html);
    final container = document.querySelector('.content');
    if (container == null) return <PicContent>[];

    final results = <PicContent>[];
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
  List<PicContent> _parseSourceType10Models(String html) {
    final document = html_parser.parse(html);
    final blogContainers = document.querySelectorAll('.blog');
    if (blogContainers.isEmpty) return <PicContent>[];

    final results = <PicContent>[];
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
}
