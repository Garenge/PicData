/// 网页内容解析工具类：从 HTML 中提取可读文本。
///
/// 目前实现比较简单：粗略移除 `<script>` / `<style>` 标签和其它 HTML 标签，
/// 然后压缩多余空白。后续如果需要更精准的正文提取，可以在这里替换为
/// 更复杂的解析方案（例如按规则提取特定节点）。
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

    final withoutTags = withoutStyle.replaceAll(
      RegExp(r'<[^>]+>'),
      ' ',
    );

    final normalized = withoutTags.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return normalized.trim();
  }
}

