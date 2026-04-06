import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/services/pic_download_oc_path.dart';
import 'package:pic_data/services/pic_download_types.dart';

/// 套图下载记录的内存仓库；UI 可 `addListener` 或通过上层状态管理订阅。
class PicSetDownloadRecordStore extends ChangeNotifier {
  PicSetDownloadRecordStore._();

  static final PicSetDownloadRecordStore instance = PicSetDownloadRecordStore._();

  final List<PicSetDownloadRecord> _records = <PicSetDownloadRecord>[];

  List<PicSetDownloadRecord> get records => List<PicSetDownloadRecord>.unmodifiable(_records);

  PicSetDownloadRecord? tryGet(String taskId) {
    for (final PicSetDownloadRecord r in _records) {
      if (r.id == taskId) {
        return r;
      }
    }
    return null;
  }

  void _replace(String taskId, PicSetDownloadRecord Function(PicSetDownloadRecord r) fn) {
    final int i = _records.indexWhere((PicSetDownloadRecord r) => r.id == taskId);
    if (i < 0) {
      return;
    }
    _records[i] = fn(_records[i]);
    notifyListeners();
  }

  /// 队列 A 入队成功时调用（与 [PicDownloadModule.enqueueDownloadSet] 衔接）。
  ///
  /// 异步计算套图目录相对应用文档目录的路径，避免把会过期的绝对路径写进记录。
  Future<void> registerEnqueued(PicSetDownloadQueueTask task) async {
    final String sub = ocDownloadSubFolderPath(
      host: task.host,
      content: task.content,
    );
    final String rel = await DownloadFileService.instance
        .relativePathFromApplicationDocumentsToSetFolder(sub);
    _records.insert(
      0,
      PicSetDownloadRecord.initialForEnqueue(
        task: task,
        localDirRelativeToApplicationDocuments: rel,
      ),
    );
    notifyListeners();
  }

  /// 工作线程开始处理该套（已出队，即将建目录/解析）。
  void markPickedUp(String taskId) {
    final DateTime now = DateTime.now();
    _replace(taskId, (PicSetDownloadRecord r) {
      return r.copyWith(
        status: PicSetDownloadTaskStatus.inProgress,
        parseStartedAt: r.parseStartedAt ?? now,
      );
    });
  }

  /// 每页解析结束后的进度（去重后的累计张数）。
  void applyParsePage(
    String taskId, {
    required int parsePagesLoaded,
    required int parseUniqueImagesSoFar,
  }) {
    _replace(taskId, (PicSetDownloadRecord r) {
      return r.copyWith(
        progress: r.progress.copyWith(
          parsePagesLoaded: parsePagesLoaded,
          parseUniqueImagesSoFar: parseUniqueImagesSoFar,
        ),
      );
    });
  }

  /// 分页链 walk 结束，[plannedImageTotal] 为去重后的总图数。
  void markParsePhaseDone(String taskId, {required int plannedImageTotal}) {
    final DateTime now = DateTime.now();
    _replace(taskId, (PicSetDownloadRecord r) {
      return r.copyWith(
        parseFinishedAt: now,
        progress: r.progress.copyWith(
          parseFinished: true,
          plannedImageTotal: plannedImageTotal,
        ),
      );
    });
  }

  /// 队列 B 单图任务结束：记录成功或失败（整套收尾时据此判断是否 [markCompleted]）。
  void recordImageJobOutcome(String taskId, {required bool success}) {
    _replace(taskId, (PicSetDownloadRecord r) {
      return r.copyWith(
        progress: r.progress.copyWith(
          imageJobsSucceeded: success
              ? r.progress.imageJobsSucceeded + 1
              : r.progress.imageJobsSucceeded,
          imageJobsFailed: success
              ? r.progress.imageJobsFailed
              : r.progress.imageJobsFailed + 1,
        ),
      );
    });
  }

  void markCompleted(String taskId) {
    final DateTime now = DateTime.now();
    _replace(taskId, (PicSetDownloadRecord r) {
      return r.copyWith(
        status: PicSetDownloadTaskStatus.completed,
        completedAt: now,
      );
    });
  }

  void markFailed(String taskId, String message) {
    _replace(taskId, (PicSetDownloadRecord r) {
      return r.copyWith(
        status: PicSetDownloadTaskStatus.failed,
        lastErrorMessage: message,
      );
    });
  }

  /// 按本地目录内实际文件数校正 [PicSetDownloadProgress.imageJobsSucceeded]（排除 `urls.txt` 等）。
  ///
  /// 仅在已结束分页解析、且已知 [PicSetDownloadProgress.plannedImageTotal] 时校正；用于 UI 与磁盘对齐。
  Future<void> syncImageProgressFromDisk() async {
    for (var i = 0; i < _records.length; i++) {
      final PicSetDownloadRecord record = _records[i];
      final PicSetDownloadProgress prog = record.progress;
      if (!prog.parseFinished || prog.plannedImageTotal == null) {
        continue;
      }
      final int planned = prog.plannedImageTotal!;
      try {
        final String abs = await DownloadFileService.instance
            .absolutePathFromApplicationDocumentsRelative(
          record.localDirRelativeToApplicationDocuments,
        );
        final Directory dir = Directory(abs);
        if (!await dir.exists()) {
          continue;
        }
        int fileCount = 0;
        await for (final FileSystemEntity entity in dir.list()) {
          if (entity is! File) {
            continue;
          }
          final String base = p.basename(entity.path);
          if (base == 'urls.txt' || base.startsWith('.')) {
            continue;
          }
          fileCount++;
        }
        final int next = fileCount > planned ? planned : fileCount;
        if (next != prog.imageJobsSucceeded) {
          _records[i] = record.copyWith(
            progress: prog.copyWith(imageJobsSucceeded: next),
          );
        }
      } catch (_) {
        // 忽略单条同步失败，避免打断整表刷新
      }
    }
    notifyListeners();
  }
}
