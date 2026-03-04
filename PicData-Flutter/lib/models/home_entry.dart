class HomeEntry {
  const HomeEntry({
    required this.title,
    required this.url,
  });

  /// 展示用标题（标签 / 入口名）
  final String title;

  /// 对应的请求 URL（可用于后续抓取或跳转）
  final String url;
}

