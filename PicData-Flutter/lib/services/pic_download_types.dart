import 'dart:async';

import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';

/// 队列 A：一次「整套」下载任务（用户触发，可多套堆积 FIFO）。
class PicSetDownloadQueueTask {
  PicSetDownloadQueueTask({
    required this.id,
    required this.content,
    this.host,
    this.replaceExistingImageFiles = false,
    Completer<void>? recordRegistered,
  }) : recordRegistered = recordRegistered ?? Completer<void>();

  final String id;
  final PicContent content;
  final PicHost? host;

  /// 为 `true` 时：本地已有同名文件则先删除再下载；默认 `false` 则跳过已存在文件。
  final bool replaceExistingImageFiles;

  /// 在 [PicSetDownloadRecordStore.registerEnqueued] 成功写入记录后 complete；
  /// 避免 worker 早于记录插入就执行 [markPickedUp] 等更新（[_replace] 会静默跳过）。
  final Completer<void> recordRegistered;

  @override
  String toString() =>
      'PicSetDownloadQueueTask(id=$id, title="${content.title}")';
}
