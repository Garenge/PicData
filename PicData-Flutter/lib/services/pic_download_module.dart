import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/services/net_client.dart';
import 'package:pic_data/services/pic_detail_page_loader.dart';
import 'package:pic_data/services/pic_download_oc_path.dart';
import 'package:pic_data/services/pic_download_types.dart';
import 'package:pic_data/services/pic_set_download_manager.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';

const String _logCtx = 'PicData-Flutter/lib/services/pic_download_module.dart';

class _UserPauseException implements Exception {}

/// 下载模块：队列 A（套图任务）+ 队列 B（单图下载）。
///
/// - **队列 A**：用户多次点击下载会 FIFO 排入；单套任务内先**分页解析完**并写入目标目录下的
///   `urls.txt`，再为该套入队全部图片；待该套所有图片任务结束（含跳过已存在）后再处理下一套。
/// - **队列 B**：单张图片 GET + 写盘，默认最多 [maxConcurrentImageDownloads] 并发。
class PicDownloadModule {
  PicDownloadModule._();

  static final PicDownloadModule instance = PicDownloadModule._();

  /// 队列 B 最大并发下载数。
  static const int maxConcurrentImageDownloads = 3;

  final PicDetailPageLoader _pageLoader = PicDetailPageLoader();
  late final PicSetDownloadManager _parse = PicSetDownloadManager(
    loader: _pageLoader,
  );

  final Queue<PicSetDownloadQueueTask> _setQueue =
      Queue<PicSetDownloadQueueTask>();
  final Set<String> _setHrefInPipeline = <String>{};
  bool _setPumpRunning = false;

  final Queue<_ImageDownloadJob> _imageQueue = Queue<_ImageDownloadJob>();
  int _imageInFlight = 0;

  /// 用户在设置中「暂停所有下载」后为 `true`；新套图不入队执行，队列 B 不再拉起新单图。
  bool _globallyPaused = false;

  /// 与 [_globallyPaused] 同步，供下载页等与 [ListenableBuilder] 组合刷新。
  final ValueNotifier<bool> globalPauseNotifier = ValueNotifier<bool>(false);

  bool get isGloballyPaused => _globallyPaused;

  void _checkUserPause() {
    if (_globallyPaused) {
      throw _UserPauseException();
    }
  }

  /// 设置页：暂停所有任务。已在内存中排队、尚未开始的套图会退回为仅库内「排队」；当前套在解析阶段会尽快结束并标记为已暂停；拉图阶段会丢弃未开始的单图任务并标记已暂停。
  void pauseAllDownloads() {
    if (_globallyPaused) {
      return;
    }
    _globallyPaused = true;
    globalPauseNotifier.value = true;
    while (_setQueue.isNotEmpty) {
      final PicSetDownloadQueueTask t = _setQueue.removeFirst();
      _setHrefInPipeline.remove(t.content.href);
    }
    _dropPendingImageJobsDueToPause();
    // ignore: avoid_print
    print('$_logCtx#pauseAllDownloads: globallyPaused=true, drained pending queues');
  }

  void _dropPendingImageJobsDueToPause() {
    while (_imageQueue.isNotEmpty) {
      final _ImageDownloadJob job = _imageQueue.removeFirst();
      job.onFinished(_ImageDownloadOutcome.kSkippedWithoutStoreUpdate);
    }
  }

  /// 下载页：解除全局暂停并按创建时间恢复 [queued] / [paused] 记录。
  void resumeDownloadsAfterUserPause() {
    _globallyPaused = false;
    globalPauseNotifier.value = false;
    final List<PicSetDownloadRecord> list = PicSetDownloadRecordStore.instance.records
        .where(
          (PicSetDownloadRecord r) =>
              r.status == PicSetDownloadTaskStatus.queued ||
              r.status == PicSetDownloadTaskStatus.paused,
        )
        .toList()
      ..sort(
        (PicSetDownloadRecord a, PicSetDownloadRecord b) =>
            a.createdAt.compareTo(b.createdAt),
      );
    for (final PicSetDownloadRecord r in list) {
      _enqueueRestoredSetTask(r.toResumeQueueTask());
    }
    // ignore: avoid_print
    print(
      '$_logCtx#resumeDownloadsAfterUserPause: '
      'globallyPaused=false reEnqueueCount=${list.length}',
    );
  }

  /// 将一整套套图下载排入队列 A（同一 [PicContent.href] 已在排队或执行中会跳过）。
  ///
  /// [replaceExistingImageFiles] 为 `true` 时，单图下载前若本地已存在则先删除再拉取；默认 `false` 则跳过已存在文件。
  void enqueueDownloadSet({
    required PicContent content,
    PicHost? host,
    bool replaceExistingImageFiles = false,
  }) {
    final href = content.href;
    if (href.isEmpty) {
      // ignore: avoid_print
      print('$_logCtx#enqueueDownloadSet: skip empty href');
      return;
    }
    if (_setHrefInPipeline.contains(href)) {
      // ignore: avoid_print
      print(
        '$_logCtx#enqueueDownloadSet: skip duplicate href already in pipeline '
        '"$href"',
      );
      return;
    }

    final task = PicSetDownloadQueueTask(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      content: content,
      host: host,
      replaceExistingImageFiles: replaceExistingImageFiles,
    );
    unawaited(() async {
      try {
        await PicSetDownloadRecordStore.instance.registerEnqueued(task);
        if (!task.recordRegistered.isCompleted) {
          task.recordRegistered.complete();
        }
      } catch (e, st) {
        if (!task.recordRegistered.isCompleted) {
          task.recordRegistered.completeError(e, st);
        }
        _setHrefInPipeline.remove(href);
        // ignore: avoid_print
        print(
          '$_logCtx#enqueueDownloadSet: registerEnqueued failed id=${task.id} '
          'error=$e',
        );
        // ignore: avoid_print
        print('  stack=$st');
      }
    }());

    if (_globallyPaused) {
      // ignore: avoid_print
      print(
        '$_logCtx#enqueueDownloadSet: globallyPaused, record only '
        'title="${task.content.title}"',
      );
      return;
    }

    _setHrefInPipeline.add(href);
    _setQueue.add(task);
    // ignore: avoid_print
    print(
      'PicDownloadModule 队列A 入队 ${task.content.title} '
      '(pending=${_setQueue.length})',
    );
    unawaited(_pumpSetQueue());
  }

  /// 冷启动在 [PicSetDownloadRecordStore.loadFromDatabaseOnStartup] 之后调用：把仍为
  /// [PicSetDownloadTaskStatus.queued] 的记录按 [PicSetDownloadRecord.createdAt] 升序重新推入队列 A
  /// （不新建库行、不改动 [PicSetDownloadQueueTask.id]）。
  void resumePersistedQueuedTasksIfAny() {
    final List<PicSetDownloadRecord> queued =
        PicSetDownloadRecordStore.instance.records
            .where(
              (PicSetDownloadRecord r) =>
                  r.status == PicSetDownloadTaskStatus.queued,
            )
            .toList()
          ..sort(
            (PicSetDownloadRecord a, PicSetDownloadRecord b) =>
                a.createdAt.compareTo(b.createdAt),
          );
    if (queued.isEmpty) {
      return;
    }
    // ignore: avoid_print
    print(
      '$_logCtx#resumePersistedQueuedTasksIfAny: reEnqueue count=${queued.length}',
    );
    for (final PicSetDownloadRecord r in queued) {
      _enqueueRestoredSetTask(r.toResumeQueueTask());
    }
  }

  /// 下载页：失败套图整表重新走解析与拉图；默认 [replaceExistingImageFiles] 为 `true`，与 [enqueueDownloadSet] 同名参数语义一致。
  Future<void> retryFailedSetDownload(
    PicSetDownloadRecord record, {
    bool replaceExistingImageFiles = true,
  }) async {
    if (record.status != PicSetDownloadTaskStatus.failed) {
      // ignore: avoid_print
      print(
        '$_logCtx#retryFailedSetDownload: skip non-failed id=${record.id} '
        'status=${record.status}',
      );
      return;
    }
    await PicSetDownloadRecordStore.instance.resetFailedRecordToQueuedForRetry(
      record.id,
    );
    final PicSetDownloadRecord? updated =
        PicSetDownloadRecordStore.instance.tryGet(record.id);
    if (updated == null || updated.status != PicSetDownloadTaskStatus.queued) {
      return;
    }
    if (_globallyPaused) {
      // ignore: avoid_print
      print(
        '$_logCtx#retryFailedSetDownload: globallyPaused, record queued only '
        'id=${record.id}',
      );
      return;
    }
    _enqueueRestoredSetTask(
      updated.toRetryQueueTask(
        replaceExistingImageFiles: replaceExistingImageFiles,
      ),
    );
  }

  void _enqueueRestoredSetTask(PicSetDownloadQueueTask task) {
    final String href = task.content.href;
    if (href.isEmpty) {
      // ignore: avoid_print
      print('$_logCtx#_enqueueRestoredSetTask: skip empty href id=${task.id}');
      return;
    }
    if (_setHrefInPipeline.contains(href)) {
      // ignore: avoid_print
      print(
        '$_logCtx#_enqueueRestoredSetTask: skip duplicate href id=${task.id} '
        'href="$href"',
      );
      return;
    }
    _setHrefInPipeline.add(href);
    _setQueue.add(task);
    // ignore: avoid_print
    print(
      '$_logCtx#_enqueueRestoredSetTask: restored id=${task.id} '
      'title="${task.content.title}" pending=${_setQueue.length}',
    );
    unawaited(_pumpSetQueue());
  }

  Future<void> _pumpSetQueue() async {
    if (_setPumpRunning) return;
    _setPumpRunning = true;
    try {
      while (_setQueue.isNotEmpty) {
        if (_globallyPaused) {
          break;
        }
        final task = _setQueue.removeFirst();
        try {
          await _processSetTask(task);
          // ignore: avoid_print
          print(
            'PicDownloadModule 队列A 完成 id=${task.id} '
            'title="${task.content.title}"',
          );
        } on _UserPauseException {
          PicSetDownloadRecordStore.instance.markPaused(task.id);
          // ignore: avoid_print
          print(
            '$_logCtx#_pumpSetQueue: userPause id=${task.id} '
            'title="${task.content.title}"',
          );
        } catch (e, st) {
          PicSetDownloadRecordStore.instance.markFailed(task.id, '$e');
          // ignore: avoid_print
          print('$_logCtx#_pumpSetQueue: task failed id=${task.id} error=$e');
          // ignore: avoid_print
          print('  stack=$st');
        } finally {
          _setHrefInPipeline.remove(task.content.href);
        }
      }
    } finally {
      _setPumpRunning = false;
    }
  }

  Future<void> _processSetTask(PicSetDownloadQueueTask task) async {
    try {
      await task.recordRegistered.future;
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '$_logCtx#_processSetTask: skip id=${task.id} record not registered: $e',
      );
      // ignore: avoid_print
      print('  stack=$st');
      return;
    }

    _checkUserPause();

    final subFolder = ocDownloadSubFolderPath(
      host: task.host,
      content: task.content,
    );
    // ignore: avoid_print
    print(
      '$_logCtx#_processSetTask: set_begin id=${task.id} '
      'title="${task.content.title}" href="${task.content.href}" '
      'subFolder="$subFolder"',
    );

    try {
      PicSetDownloadRecordStore.instance.markPickedUp(task.id);

      _checkUserPause();

      final seenUrl = <String>{};
      final pendingImages = <_PendingSetImage>[];
      var parsePagesLoaded = 0;

      final setDir = await DownloadFileService.instance.ensureSubDirectory(
        subFolder,
      );
      final urlsFile = File('${setDir.path}/urls.txt');
      await urlsFile.writeAsString('', flush: true);

      await _parse.walkPagesForSet(
        content: task.content,
        host: task.host,
        logPages: false,
        onPage: (page) async {
          _checkUserPause();
          final chunk = StringBuffer();
          for (final url in page.imageUrls) {
            if (!seenUrl.add(url)) {
              continue;
            }
            pendingImages.add(
              _PendingSetImage(url: url, detailHref: page.href),
            );
            chunk.writeln(url);
          }
          if (chunk.isNotEmpty) {
            await urlsFile.writeAsString(
              chunk.toString(),
              mode: FileMode.append,
              flush: true,
            );
          }
          parsePagesLoaded++;
          PicSetDownloadRecordStore.instance.applyParsePage(
            task.id,
            parsePagesLoaded: parsePagesLoaded,
            parseUniqueImagesSoFar: pendingImages.length,
          );
        },
      );

      _checkUserPause();

      PicSetDownloadRecordStore.instance.markParsePhaseDone(
        task.id,
        plannedImageTotal: pendingImages.length,
      );

      // ignore: avoid_print
      print(
        '$_logCtx#_processSetTask: urls_txt_appended_per_page '
        'path="$subFolder/urls.txt" count=${pendingImages.length}',
      );

      var parseDone = false;
      var inFlightCount = 0;
      final completer = Completer<void>();

      void tryComplete() {
        if (parseDone && inFlightCount <= 0 && !completer.isCompleted) {
          completer.complete();
        }
      }

      // ignore: avoid_print
      print(
        '$_logCtx#_processSetTask: set_enqueue_images '
        'id=${task.id} count=${pendingImages.length}',
      );

      for (var i = 0; i < pendingImages.length; i++) {
        _checkUserPause();
        final pending = pendingImages[i];
        final seq = i + 1;
        inFlightCount++;
        final fileName = ocSequentialImageFileName(seq, pending.url);
        final file = await DownloadFileService.instance.prepareDownloadFile(
          fileName: fileName,
          subFolder: subFolder,
        );
        final headers = PicDetailPageLoader.buildDetailRequestHeaders(
          detailUrl: pending.detailHref,
          host: task.host,
        );
        _enqueueImage(
          _ImageDownloadJob(
            setTitle: task.content.title,
            fileName: fileName,
            sequence: seq,
            imageUrl: pending.url,
            headers: headers,
            targetFile: file,
            replaceExistingImageFiles: task.replaceExistingImageFiles,
            onFinished: (_ImageDownloadOutcome outcome) {
              if (!outcome.skippedWithoutStoreUpdate) {
                PicSetDownloadRecordStore.instance.recordImageJobOutcome(
                  task.id,
                  success: outcome.success,
                  failureDetail: outcome.success
                      ? null
                      : PicSetDownloadFailureDetail(
                          sequence: seq,
                          fileName: fileName,
                          imageUrl: pending.url,
                          detailHref: pending.detailHref,
                          reason: outcome.failureReason ?? 'unknown',
                          occurredAt: DateTime.now(),
                        ),
                );
              }
              inFlightCount--;
              tryComplete();
            },
          ),
        );
      }

      parseDone = true;
      tryComplete();
      await completer.future;

      if (_globallyPaused) {
        PicSetDownloadRecordStore.instance.markPaused(task.id);
        return;
      }

      final PicSetDownloadRecord? sumRec = PicSetDownloadRecordStore.instance
          .tryGet(task.id);
      final int plannedTotal =
          sumRec?.progress.plannedImageTotal ?? pendingImages.length;
      final int succeeded = sumRec?.progress.imageJobsSucceeded ?? 0;
      final int failedCount = sumRec?.progress.imageJobsFailed ?? 0;

      if (plannedTotal == 0 || succeeded == plannedTotal) {
        PicSetDownloadRecordStore.instance.markCompleted(task.id);
        // ignore: avoid_print
        print(
          '$_logCtx#_processSetTask: set_end id=${task.id} '
          'title="${task.content.title}" status=ok '
          'urls=${pendingImages.length}',
        );
      } else {
        PicSetDownloadRecordStore.instance.markFailed(
          task.id,
          '图片未全部下载成功：成功 $succeeded / 共 $plannedTotal，失败 $failedCount',
        );
        // ignore: avoid_print
        print(
          '$_logCtx#_processSetTask: set_end id=${task.id} '
          'title="${task.content.title}" status=incomplete_downloads '
          'ok=$succeeded planned=$plannedTotal failed=$failedCount',
        );
      }
    } on _UserPauseException {
      rethrow;
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '$_logCtx#_processSetTask: set_end id=${task.id} '
        'title="${task.content.title}" status=error error=$e',
      );
      // ignore: avoid_print
      print('  stack=$st');
      rethrow;
    }
  }

  void _enqueueImage(_ImageDownloadJob job) {
    _imageQueue.add(job);
    _pumpImageQueue();
  }

  void _pumpImageQueue() {
    while (!_globallyPaused &&
        _imageInFlight < maxConcurrentImageDownloads &&
        _imageQueue.isNotEmpty) {
      _imageInFlight++;
      final job = _imageQueue.removeFirst();
      unawaited(_runOneImageDownload(job));
    }
  }

  Future<void> _runOneImageDownload(_ImageDownloadJob job) async {
    final PicSingleImageRetryResult result = await _downloadImageToFile(
      setTitle: job.setTitle,
      fileName: job.fileName,
      sequence: job.sequence,
      imageUrl: job.imageUrl,
      headers: job.headers,
      targetFile: job.targetFile,
      replaceExistingImageFiles: job.replaceExistingImageFiles,
    );
    // ignore: avoid_print
    try {
      job.onFinished(
        _ImageDownloadOutcome(
          success: result.success,
          failureReason: result.failureReason,
        ),
      );
    } finally {
      _imageInFlight--;
      _pumpImageQueue();
    }
  }

  Future<PicSingleImageRetryResult> retryFailedImage({
    required PicSetDownloadRecord record,
    required PicSetDownloadFailureDetail detail,
    bool replaceExistingImageFile = true,
  }) async {
    final String absDir = await DownloadFileService.instance
        .absolutePathFromApplicationDocumentsRelative(
          record.localDirRelativeToApplicationDocuments,
        );
    final File targetFile = File(p.join(absDir, detail.fileName));
    final String detailUrl =
        (detail.detailHref != null && detail.detailHref!.isNotEmpty)
        ? detail.detailHref!
        : record.entryDetailHref;
    final Map<String, String>? headers =
        PicDetailPageLoader.buildDetailRequestHeaders(
          detailUrl: detailUrl,
          host: record.host.toLoosePicHost(),
        );
    return _downloadImageToFile(
      setTitle: record.title,
      fileName: detail.fileName,
      sequence: detail.sequence,
      imageUrl: detail.imageUrl,
      headers: headers,
      targetFile: targetFile,
      replaceExistingImageFiles: replaceExistingImageFile,
    );
  }

  Future<PicSingleImageRetryResult> _downloadImageToFile({
    required String setTitle,
    required String fileName,
    required int sequence,
    required String imageUrl,
    required Map<String, String>? headers,
    required File targetFile,
    required bool replaceExistingImageFiles,
  }) async {
    // ignore: avoid_print
    print(
      '$_logCtx#_downloadImageToFile: file_begin '
      'set="$setTitle" file="$fileName" seq=$sequence',
    );
    try {
      if (await targetFile.exists()) {
        if (replaceExistingImageFiles) {
          await targetFile.delete();
          // ignore: avoid_print
          print(
            '$_logCtx#_downloadImageToFile: deleted_existing '
            'set="$setTitle" file="$fileName" seq=$sequence',
          );
        } else {
          // ignore: avoid_print
          print(
            '$_logCtx#_downloadImageToFile: file_end '
            'set="$setTitle" file="$fileName" seq=$sequence status=skipped_exists',
          );
          return const PicSingleImageRetryResult(success: true);
        }
      }
      final List<int> bytes = await NetClient.instance.getBytes(
        imageUrl,
        headers: headers,
      );
      await targetFile.writeAsBytes(bytes);
      // ignore: avoid_print
      print(
        '$_logCtx#_downloadImageToFile: file_end '
        'set="$setTitle" file="$fileName" seq=$sequence status=ok bytes=${bytes.length}',
      );
      return const PicSingleImageRetryResult(success: true);
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '$_logCtx#_downloadImageToFile: file_end '
        'set="$setTitle" file="$fileName" seq=$sequence status=failed error=$e',
      );
      // ignore: avoid_print
      print('  stack=$st');
      return PicSingleImageRetryResult(success: false, failureReason: '$e');
    }
  }
}

class PicSingleImageRetryResult {
  const PicSingleImageRetryResult({required this.success, this.failureReason});

  final bool success;
  final String? failureReason;
}

class _ImageDownloadJob {
  _ImageDownloadJob({
    required this.setTitle,
    required this.fileName,
    required this.sequence,
    required this.imageUrl,
    required this.headers,
    required this.targetFile,
    required this.replaceExistingImageFiles,
    required this.onFinished,
  });

  final String setTitle;
  final String fileName;

  /// 套图内从 1 起的序号（与本地文件名一致）。
  final int sequence;
  final String imageUrl;
  final Map<String, String>? headers;
  final File targetFile;
  final bool replaceExistingImageFiles;

  /// [success]：已落盘或本地已存在；`false` 表示下载/写盘失败。
  final void Function(_ImageDownloadOutcome outcome) onFinished;
}

class _ImageDownloadOutcome {
  const _ImageDownloadOutcome({
    required this.success,
    this.failureReason,
    this.skippedWithoutStoreUpdate = false,
  });

  /// 全局暂停时从队列 B 丢弃的占位任务：只减少 in-flight 计数，不写 [PicSetDownloadRecordStore]。
  static const _ImageDownloadOutcome kSkippedWithoutStoreUpdate =
      _ImageDownloadOutcome(
    success: false,
    failureReason: null,
    skippedWithoutStoreUpdate: true,
  );

  final bool success;
  final String? failureReason;
  final bool skippedWithoutStoreUpdate;
}

class _PendingSetImage {
  const _PendingSetImage({required this.url, required this.detailHref});

  final String url;
  final String detailHref;
}
