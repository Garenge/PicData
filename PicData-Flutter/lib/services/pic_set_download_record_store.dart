import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/persistence/pic_database.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/services/pic_download_oc_path.dart';
import 'package:pic_data/services/pic_download_types.dart';

const String _logStore =
    'PicData-Flutter/lib/services/pic_set_download_record_store.dart';

/// 套图下载记录的内存仓库；UI 可 `addListener` 或通过上层状态管理订阅。
class PicSetDownloadRecordStore extends ChangeNotifier {
  PicSetDownloadRecordStore._();

  static final PicSetDownloadRecordStore instance =
      PicSetDownloadRecordStore._();

  final List<PicSetDownloadRecord> _records = <PicSetDownloadRecord>[];

  /// 冷启动时 [main] 在 [PicDatabase.init] 之后调用：从 SQLite 载入，并将非已完成/失败/已暂停记录重置为 [PicSetDownloadTaskStatus.queued] 后写回库。
  Future<void> loadFromDatabaseOnStartup() async {
    final List<PicSetDownloadRecord> list = await PicDatabase
        .instance
        .downloadRecords
        .queryAllOrderByCreatedDesc();
    _records.clear();
    for (final PicSetDownloadRecord r in list) {
      PicSetDownloadRecord row = r;
      if (r.status != PicSetDownloadTaskStatus.completed &&
          r.status != PicSetDownloadTaskStatus.failed &&
          r.status != PicSetDownloadTaskStatus.paused) {
        row = r.resetToQueuedPreservingIdentity();
        await PicDatabase.instance.downloadRecords.upsert(row);
      }
      _records.add(row);
    }
    notifyListeners();
  }

  void _persist(PicSetDownloadRecord r) {
    unawaited(() async {
      try {
        await PicDatabase.instance.downloadRecords.upsert(r);
      } catch (e, st) {
        // ignore: avoid_print
        print('$_logStore#_persist: failed id=${r.id} error=$e');
        // ignore: avoid_print
        print('  stack=$st');
      }
    }());
  }

  List<PicSetDownloadRecord> get records =>
      List<PicSetDownloadRecord>.unmodifiable(_records);

  /// 已成功下载完成的套图详情页 [href]，与列表里 [PicContent.href] 对齐。
  Set<String> get completedContentHrefSet {
    return _records
        .where(
          (PicSetDownloadRecord r) =>
              r.status == PicSetDownloadTaskStatus.completed,
        )
        .map((PicSetDownloadRecord r) => r.contentHref)
        .where((String h) => h.isNotEmpty)
        .toSet();
  }

  /// 下载列表中仍保留记录的 [contentHref]（排队中 / 进行中 / 已完成 / 失败），
  /// 与 [PicContent.href] 对齐；用于隐藏「再次加入队列」的下载按钮。
  Set<String> get trackedContentHrefSet {
    return _records
        .map((PicSetDownloadRecord r) => r.contentHref)
        .where((String h) => h.isNotEmpty)
        .toSet();
  }

  PicSetDownloadRecord? tryGet(String taskId) {
    for (final PicSetDownloadRecord r in _records) {
      if (r.id == taskId) {
        return r;
      }
    }
    return null;
  }

  /// 与 [trackedContentHrefSet] 同源：按详情/列表 [PicContent.href] 找当前仍保留的记录（任意状态）。
  PicSetDownloadRecord? tryGetRecordByContentHref(String contentHref) {
    if (contentHref.isEmpty) {
      return null;
    }
    for (final PicSetDownloadRecord r in _records) {
      if (r.contentHref == contentHref) {
        return r;
      }
    }
    return null;
  }

  /// 按当前本地套图目录精确查找下载记录；用于从文件浏览器回跳详情页。
  Future<PicSetDownloadRecord?> tryGetRecordByLocalDirectoryPath(
    String absolutePath,
  ) async {
    final String normalizedTarget = p.normalize(absolutePath);
    for (final PicSetDownloadRecord record in _records) {
      final String abs = await DownloadFileService.instance
          .absolutePathFromApplicationDocumentsRelative(
            record.localDirRelativeToApplicationDocuments,
          );
      if (p.equals(p.normalize(abs), normalizedTarget)) {
        return record;
      }
    }
    return null;
  }

  /// 从列表与 SQLite 中移除一条记录。
  ///
  /// [deleteLocalFiles] 为 `true` 时，同时删除 [PicSetDownloadRecord.localDirRelativeToApplicationDocuments]
  /// 对应的套图目录（递归）；默认仅删库与内存，保留本机已下载文件。
  Future<void> removeRecord(
    String taskId, {
    bool deleteLocalFiles = false,
  }) async {
    final int i = _records.indexWhere(
      (PicSetDownloadRecord r) => r.id == taskId,
    );
    if (i < 0) {
      return;
    }
    final PicSetDownloadRecord rec = _records[i];
    if (deleteLocalFiles) {
      try {
        final String abs = await DownloadFileService.instance
            .absolutePathFromApplicationDocumentsRelative(
              rec.localDirRelativeToApplicationDocuments,
            );
        final Directory dir = Directory(abs);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e, st) {
        // ignore: avoid_print
        print(
          '$_logStore#removeRecord: deleteLocalFolder failed id=$taskId error=$e',
        );
        // ignore: avoid_print
        print('  stack=$st');
        rethrow;
      }
    }
    try {
      await PicDatabase.instance.downloadRecords.deleteById(taskId);
    } catch (e, st) {
      // ignore: avoid_print
      print('$_logStore#removeRecord: deleteById failed id=$taskId error=$e');
      // ignore: avoid_print
      print('  stack=$st');
      rethrow;
    }
    final int j = _records.indexWhere(
      (PicSetDownloadRecord r) => r.id == taskId,
    );
    if (j >= 0) {
      _records.removeAt(j);
    }
    notifyListeners();
  }

  /// 取消进行中的套图任务时，先把记录落为终态，再从内存与 SQLite 删除。
  Future<void> finishAndRemoveRecord(
    String taskId, {
    bool deleteLocalFiles = false,
  }) async {
    final int i = _records.indexWhere(
      (PicSetDownloadRecord r) => r.id == taskId,
    );
    if (i < 0) {
      return;
    }
    final PicSetDownloadRecord finished = _records[i].copyWith(
      status: PicSetDownloadTaskStatus.failed,
      lastErrorMessage: '用户停止并删除任务',
    );
    try {
      await PicDatabase.instance.downloadRecords.upsert(finished);
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '$_logStore#finishAndRemoveRecord: upsert finished failed '
        'id=$taskId error=$e',
      );
      // ignore: avoid_print
      print('  stack=$st');
      rethrow;
    }
    _records[i] = finished;
    notifyListeners();
    await removeRecord(taskId, deleteLocalFiles: deleteLocalFiles);
  }

  /// 删除本地文件浏览器中的目录后，按目录相对路径同步移除下载记录。
  Future<int> removeRecordsUnderLocalPath(String absolutePath) async {
    final String normalizedTarget = p.normalize(absolutePath);
    final List<String> idsToRemove = <String>[];
    for (final PicSetDownloadRecord record in _records) {
      final String abs = await DownloadFileService.instance
          .absolutePathFromApplicationDocumentsRelative(
            record.localDirRelativeToApplicationDocuments,
          );
      if (_isSameOrChildPath(p.normalize(abs), normalizedTarget)) {
        idsToRemove.add(record.id);
      }
    }
    for (final String id in idsToRemove) {
      await removeRecord(id);
    }
    return idsToRemove.length;
  }

  bool _isSameOrChildPath(String path, String parent) {
    if (path == parent) {
      return true;
    }
    final String prefix = parent.endsWith(p.separator)
        ? parent
        : '$parent${p.separator}';
    return path.startsWith(prefix);
  }

  void _replace(
    String taskId,
    PicSetDownloadRecord Function(PicSetDownloadRecord r) fn,
  ) {
    final int i = _records.indexWhere(
      (PicSetDownloadRecord r) => r.id == taskId,
    );
    if (i < 0) {
      return;
    }
    _records[i] = fn(_records[i]);
    _persist(_records[i]);
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
    final PicSetDownloadRecord rec = PicSetDownloadRecord.initialForEnqueue(
      task: task,
      localDirRelativeToApplicationDocuments: rel,
    );
    _records.insert(0, rec);
    _persist(rec);
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
  void recordImageJobOutcome(
    String taskId, {
    required bool success,
    PicSetDownloadFailureDetail? failureDetail,
  }) {
    _replace(taskId, (PicSetDownloadRecord r) {
      final List<PicSetDownloadFailureDetail> nextFailureDetails = success
          ? r.failureDetails
          : <PicSetDownloadFailureDetail>[...r.failureDetails, ?failureDetail];
      return r.copyWith(
        progress: r.progress.copyWith(
          imageJobsSucceeded: success
              ? r.progress.imageJobsSucceeded + 1
              : r.progress.imageJobsSucceeded,
          imageJobsFailed: success
              ? r.progress.imageJobsFailed
              : r.progress.imageJobsFailed + 1,
        ),
        failureDetails: nextFailureDetails,
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

  /// 用户「暂停所有下载」：保留当前进度，停止继续拉取。
  void markPaused(String taskId) {
    _replace(taskId, (PicSetDownloadRecord r) {
      return r.copyWith(status: PicSetDownloadTaskStatus.paused);
    });
  }

  /// 将可重新下载的终态记录重置为 [PicSetDownloadTaskStatus.queued] 并写库。
  Future<void> resetRecordToQueuedForRedownload(String taskId) async {
    final int i = _records.indexWhere(
      (PicSetDownloadRecord r) => r.id == taskId,
    );
    if (i < 0) {
      return;
    }
    final PicSetDownloadRecord r = _records[i];
    if (!r.status.canRedownload) {
      return;
    }
    final PicSetDownloadRecord next = r.resetToQueuedPreservingIdentity();
    try {
      await PicDatabase.instance.downloadRecords.upsert(next);
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '$_logStore#resetRecordToQueuedForRedownload: upsert failed id=$taskId error=$e',
      );
      // ignore: avoid_print
      print('  stack=$st');
      rethrow;
    }
    _records[i] = next;
    notifyListeners();
  }

  void applyFailureRetryResult(
    String taskId, {
    required PicSetDownloadFailureDetail target,
    required bool success,
    String? failureReason,
  }) {
    _replace(taskId, (PicSetDownloadRecord r) {
      final List<PicSetDownloadFailureDetail> current = r.failureDetails;
      final int idx = current.indexWhere(
        (PicSetDownloadFailureDetail d) => d.identityKey == target.identityKey,
      );
      if (idx < 0) {
        return r;
      }
      final List<PicSetDownloadFailureDetail> nextDetails =
          <PicSetDownloadFailureDetail>[...current];
      PicSetDownloadProgress nextProgress = r.progress;
      PicSetDownloadTaskStatus nextStatus = r.status;
      DateTime? nextCompletedAt = r.completedAt;
      String? nextMessage = r.lastErrorMessage;

      if (success) {
        nextDetails.removeAt(idx);
        nextProgress = nextProgress.copyWith(
          imageJobsSucceeded: nextProgress.imageJobsSucceeded + 1,
          imageJobsFailed: nextProgress.imageJobsFailed > 0
              ? nextProgress.imageJobsFailed - 1
              : 0,
        );
        if (nextDetails.isEmpty) {
          nextStatus = PicSetDownloadTaskStatus.completed;
          nextCompletedAt = DateTime.now();
          nextMessage = null;
        } else {
          nextStatus = PicSetDownloadTaskStatus.failed;
          nextMessage = '仍有 ${nextDetails.length} 张失败，可继续重试';
        }
      } else {
        nextDetails[idx] = PicSetDownloadFailureDetail(
          sequence: target.sequence,
          fileName: target.fileName,
          imageUrl: target.imageUrl,
          detailHref: target.detailHref,
          reason: failureReason ?? target.reason,
          occurredAt: DateTime.now(),
        );
        nextStatus = PicSetDownloadTaskStatus.failed;
        nextMessage = '重试失败：${failureReason ?? target.reason}';
      }

      return PicSetDownloadRecord(
        id: r.id,
        contentHref: r.contentHref,
        title: r.title,
        thumbnailUrl: r.thumbnailUrl,
        entryDetailHref: r.entryDetailHref,
        host: r.host,
        status: nextStatus,
        progress: nextProgress,
        createdAt: r.createdAt,
        parseStartedAt: r.parseStartedAt,
        parseFinishedAt: r.parseFinishedAt,
        completedAt: nextCompletedAt,
        lastErrorMessage: nextMessage,
        failureDetails: List<PicSetDownloadFailureDetail>.unmodifiable(
          nextDetails,
        ),
        localDirRelativeToApplicationDocuments:
            r.localDirRelativeToApplicationDocuments,
        thumbnailHttpHeaders: r.thumbnailHttpHeaders,
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
          final PicSetDownloadRecord updated = record.copyWith(
            progress: prog.copyWith(imageJobsSucceeded: next),
          );
          _records[i] = updated;
          _persist(updated);
        }
      } catch (_) {
        // 忽略单条同步失败，避免打断整表刷新
      }
    }
    notifyListeners();
  }
}
