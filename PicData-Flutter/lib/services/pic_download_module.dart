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

/// 下载模块：队列 A（套图任务）+ 队列 B（单图下载），解析与下载并行。
///
/// - **队列 A**：用户多次点击下载会 FIFO 排入，同一时间只**跑完一整套**（分页解析 +
///   该套所有入队图片下载完成）再处理下一套。
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
    var parseDone = false;
    var pendingImages = 0;
    final completer = Completer<void>();

    void tryComplete() {
      if (parseDone && pendingImages <= 0 && !completer.isCompleted) {
        completer.complete();
      }
    }

    final subFolder = ocDownloadSubFolderPath(
      host: task.host,
      content: task.content,
    );
    final seenUrl = <String>{};

    await _parse.walkPagesForSet(
      content: task.content,
      host: task.host,
      logPages: false,
      onPage: (page) async {
        for (final url in page.imageUrls) {
          if (!seenUrl.add(url)) {
            continue;
          }
          pendingImages++;
          final fileName = ocImageFileNameFromImageUrl(url);
          final file = await DownloadFileService.instance.prepareDownloadFile(
            fileName: fileName,
            subFolder: subFolder,
          );
          final headers = PicDetailPageLoader.buildDetailRequestHeaders(
            detailUrl: page.href,
            host: task.host,
          );
          _enqueueImage(
            _ImageDownloadJob(
              imageUrl: url,
              headers: headers,
              targetFile: file,
              onFinished: () {
                pendingImages--;
                tryComplete();
              },
            ),
          );
        }
      },
    );

    parseDone = true;
    tryComplete();
    await completer.future;
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
    try {
      if (await job.targetFile.exists()) {
        // ignore: avoid_print
        print(
          '$_logCtx#_runOneImageDownload: skip existing '
          '${job.targetFile.path}',
        );
        return;
      }
      final bytes = await NetClient.instance.getBytes(
        job.imageUrl,
        headers: job.headers,
      );
      await job.targetFile.writeAsBytes(bytes);
    } catch (e, st) {
      // ignore: avoid_print
      print(
        '$_logCtx#_runOneImageDownload: failed '
        'file=${job.targetFile.path} url=${job.imageUrl} error=$e',
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
    required this.imageUrl,
    required this.headers,
    required this.targetFile,
    required this.onFinished,
  });

  final String imageUrl;
  final Map<String, String>? headers;
  final File targetFile;
  final void Function() onFinished;
}
