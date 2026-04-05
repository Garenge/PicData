import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/services/net_client.dart';
import 'package:pic_data/services/pic_detail_page_loader.dart';
import 'package:pic_data/services/pic_download_oc_path.dart';
import 'package:pic_data/services/pic_download_types.dart';
import 'package:pic_data/services/pic_set_download_manager.dart';

const String _logCtx = 'PicData-Flutter/lib/services/pic_download_module.dart';

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
  late final PicSetDownloadManager _parse =
      PicSetDownloadManager(loader: _pageLoader);

  final Queue<PicSetDownloadQueueTask> _setQueue = Queue<PicSetDownloadQueueTask>();
  final Set<String> _setHrefInPipeline = <String>{};
  bool _setPumpRunning = false;

  final Queue<_ImageDownloadJob> _imageQueue = Queue<_ImageDownloadJob>();
  int _imageInFlight = 0;

  /// 将一整套套图下载排入队列 A（同一 [PicContent.href] 已在排队或执行中会跳过）。
  void enqueueDownloadSet({
    required PicContent content,
    PicHost? host,
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
    _setHrefInPipeline.add(href);

    final task = PicSetDownloadQueueTask(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      content: content,
      host: host,
    );
    _setQueue.add(task);
    // ignore: avoid_print
    print(
      'PicDownloadModule 队列A 入队 ${task.content.title} '
      '(pending=${_setQueue.length})',
    );
    unawaited(_pumpSetQueue());
  }

  Future<void> _pumpSetQueue() async {
    if (_setPumpRunning) return;
    _setPumpRunning = true;
    try {
      while (_setQueue.isNotEmpty) {
        final task = _setQueue.removeFirst();
        try {
          await _processSetTask(task);
          // ignore: avoid_print
          print(
            'PicDownloadModule 队列A 完成 id=${task.id} '
            'title="${task.content.title}"',
          );
        } catch (e, st) {
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
      final seenUrl = <String>{};
      final pendingImages = <_PendingSetImage>[];

      await _parse.walkPagesForSet(
        content: task.content,
        host: task.host,
        logPages: false,
        onPage: (page) async {
          for (final url in page.imageUrls) {
            if (!seenUrl.add(url)) {
              continue;
            }
            pendingImages.add(
              _PendingSetImage(url: url, detailHref: page.href),
            );
          }
        },
      );

      final setDir =
          await DownloadFileService.instance.ensureSubDirectory(subFolder);
      final urlsFile = File('${setDir.path}/urls.txt');
      await urlsFile.writeAsString(
        '${pendingImages.map((e) => e.url).join('\n')}\n',
      );
      // ignore: avoid_print
      print(
        '$_logCtx#_processSetTask: urls_txt_written '
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
            sequence: seq,
            imageUrl: pending.url,
            headers: headers,
            targetFile: file,
            onFinished: () {
              inFlightCount--;
              tryComplete();
            },
          ),
        );
      }

      parseDone = true;
      tryComplete();
      await completer.future;

      // ignore: avoid_print
      print(
        '$_logCtx#_processSetTask: set_end id=${task.id} '
        'title="${task.content.title}" status=ok '
        'urls=${pendingImages.length}',
      );
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
    while (_imageInFlight < maxConcurrentImageDownloads &&
        _imageQueue.isNotEmpty) {
      _imageInFlight++;
      final job = _imageQueue.removeFirst();
      unawaited(_runOneImageDownload(job));
    }
  }

  Future<void> _runOneImageDownload(_ImageDownloadJob job) async {
    // ignore: avoid_print
    print('_runOneImageDownload: file_begin seq=${job.sequence}');
    try {
      if (await job.targetFile.exists()) {
        // ignore: avoid_print
        print(
          '_runOneImageDownload: file_end seq=${job.sequence} status=skipped_exists',
        );
        return;
      }
      final bytes = await NetClient.instance.getBytes(
        job.imageUrl,
        headers: job.headers,
      );
      await job.targetFile.writeAsBytes(bytes);
      // ignore: avoid_print
      print(
        '_runOneImageDownload: file_end seq=${job.sequence} '
        'status=ok bytes=${bytes.length}',
      );
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '_runOneImageDownload: file_end seq=${job.sequence} '
        'status=failed error=$e',
      );
      // ignore: avoid_print
      print('  stack=$st');
    } finally {
      try {
        job.onFinished();
      } finally {
        _imageInFlight--;
        _pumpImageQueue();
      }
    }
  }
}

class _ImageDownloadJob {
  _ImageDownloadJob({
    required this.sequence,
    required this.imageUrl,
    required this.headers,
    required this.targetFile,
    required this.onFinished,
  });

  /// 套图内从 1 起的序号（与本地文件名一致）。
  final int sequence;
  final String imageUrl;
  final Map<String, String>? headers;
  final File targetFile;
  final void Function() onFinished;
}

class _PendingSetImage {
  const _PendingSetImage({required this.url, required this.detailHref});

  final String url;
  final String detailHref;
}
