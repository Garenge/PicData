class PicContent {
  PicContent({
    required this.title,
    required this.href,
    required this.thumbnail,
    this.isDownloaded,
  });

  final String title;
  final String href;
  final String thumbnail;
  final bool? isDownloaded;
}
