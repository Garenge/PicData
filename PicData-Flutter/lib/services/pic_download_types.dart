import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';

/// 队列 A：一次「整套」下载任务（用户触发，可多套堆积 FIFO）。
class PicSetDownloadQueueTask {
  PicSetDownloadQueueTask({
    required this.id,
    required this.content,
    this.host,
  });

  final String id;
  final PicContent content;
  final PicHost? host;

  @override
  String toString() =>
      'PicSetDownloadQueueTask(id=$id, title="${content.title}")';
}
