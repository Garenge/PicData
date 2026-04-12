import 'dart:async';

import 'package:pic_data/models/pic_content.dart';
import 'package:pic_data/models/pic_net_models.dart';
import 'package:pic_data/services/pic_download_types.dart';
import 'package:pic_data/utils/gallery_list_image_headers.dart';

/// 与 [PicDownloadModule] 队列 A 中一次套图任务对应；[id] 与 [PicSetDownloadQueueTask.id] 一致。
enum PicSetDownloadTaskStatus {
  /// 已入队，工作协程尚未取走任务。
  queued,

  /// 已开始处理（含分页解析与后续单图下载）。
  inProgress,

  /// 用户从设置触发「暂停所有」后保留进度；需在下载页点「开始下载」继续。
  paused,

  completed,
  failed,
}

/// Host 快照，避免持久化/UI 依赖可变 [PicHost] 引用。
class PicHostSnapshot {
  const PicHostSnapshot({
    required this.title,
    this.hostUrl,
    this.mark,
    this.referer,
    this.sourceType,
  });

  final String title;
  final String? hostUrl;
  final String? mark;
  final String? referer;

  /// 与 [PicHost.sourceType] 一致，便于后续跳转详情页、解析规则对齐。
  final int? sourceType;

  factory PicHostSnapshot.fromHost(PicHost? host) {
    if (host == null) {
      return const PicHostSnapshot(title: '');
    }
    return PicHostSnapshot(
      title: host.title,
      hostUrl: host.hostUrl,
      mark: host.mark,
      referer: host.referer,
      sourceType: host.sourceType,
    );
  }

  /// 用快照字段拼最小 [PicHost]，便于 `PicDetailPage` 等与列表行为对齐（无完整 urls 等配置）。
  PicHost toLoosePicHost() {
    return PicHost(
      title: title,
      sourceType: sourceType,
      hostUrl: hostUrl,
      referer: referer,
      mark: mark,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    'hostUrl': hostUrl,
    'mark': mark,
    'referer': referer,
    'sourceType': sourceType,
  };

  factory PicHostSnapshot.fromJson(Map<String, dynamic> json) {
    return PicHostSnapshot(
      title: json['title'] as String? ?? '',
      hostUrl: json['hostUrl'] as String?,
      mark: json['mark'] as String?,
      referer: json['referer'] as String?,
      sourceType: (json['sourceType'] as num?)?.toInt(),
    );
  }
}

/// 解析阶段分母未知；[plannedImageTotal] 仅在 [parseFinished] 之后有值。
class PicSetDownloadProgress {
  const PicSetDownloadProgress({
    this.parsePagesLoaded = 0,
    this.parseUniqueImagesSoFar = 0,
    this.parseFinished = false,
    this.plannedImageTotal,
    this.imageJobsSucceeded = 0,
    this.imageJobsFailed = 0,
    this.parseStoppedByCycle = false,
  });

  final int parsePagesLoaded;
  final int parseUniqueImagesSoFar;
  final bool parseFinished;
  final int? plannedImageTotal;

  /// 单图任务成功（含「本地已存在跳过下载」）。
  final int imageJobsSucceeded;

  /// 单图任务失败（网络/写盘等）。
  final int imageJobsFailed;

  final bool parseStoppedByCycle;

  /// 已结束的单图任务数（成功 + 失败），用于进度 `下载 x/total`。
  int get imageJobsFinished => imageJobsSucceeded + imageJobsFailed;

  PicSetDownloadProgress copyWith({
    int? parsePagesLoaded,
    int? parseUniqueImagesSoFar,
    bool? parseFinished,
    int? plannedImageTotal,
    int? imageJobsSucceeded,
    int? imageJobsFailed,
    bool? parseStoppedByCycle,
  }) {
    return PicSetDownloadProgress(
      parsePagesLoaded: parsePagesLoaded ?? this.parsePagesLoaded,
      parseUniqueImagesSoFar:
          parseUniqueImagesSoFar ?? this.parseUniqueImagesSoFar,
      parseFinished: parseFinished ?? this.parseFinished,
      plannedImageTotal: plannedImageTotal ?? this.plannedImageTotal,
      imageJobsSucceeded: imageJobsSucceeded ?? this.imageJobsSucceeded,
      imageJobsFailed: imageJobsFailed ?? this.imageJobsFailed,
      parseStoppedByCycle: parseStoppedByCycle ?? this.parseStoppedByCycle,
    );
  }
}

/// 单图下载失败明细：用于落库并在「失败」卡片查看。
class PicSetDownloadFailureDetail {
  const PicSetDownloadFailureDetail({
    required this.sequence,
    required this.fileName,
    required this.imageUrl,
    required this.reason,
    required this.occurredAt,
    this.detailHref,
  });

  final int sequence;
  final String fileName;
  final String imageUrl;
  final String reason;
  final DateTime occurredAt;
  final String? detailHref;

  String get identityKey => '$sequence|$fileName|$imageUrl';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sequence': sequence,
    'fileName': fileName,
    'imageUrl': imageUrl,
    'reason': reason,
    'occurredAtMs': occurredAt.millisecondsSinceEpoch,
    'detailHref': detailHref,
  };

  factory PicSetDownloadFailureDetail.fromJson(Map<String, dynamic> json) {
    return PicSetDownloadFailureDetail(
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      fileName: json['fileName'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      reason: json['reason'] as String? ?? 'unknown',
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        (json['occurredAtMs'] as num?)?.toInt() ?? 0,
      ),
      detailHref: json['detailHref'] as String?,
    );
  }
}

class PicSetDownloadRecord {
  const PicSetDownloadRecord({
    required this.id,
    required this.contentHref,
    required this.title,
    required this.thumbnailUrl,
    required this.entryDetailHref,
    required this.host,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.parseStartedAt,
    this.parseFinishedAt,
    this.completedAt,
    this.lastErrorMessage,
    this.failureDetails = const <PicSetDownloadFailureDetail>[],
    required this.localDirRelativeToApplicationDocuments,
    required this.thumbnailHttpHeaders,
  });

  final String id;
  final String contentHref;
  final String title;
  final String thumbnailUrl;
  final String entryDetailHref;
  final PicHostSnapshot host;
  final PicSetDownloadTaskStatus status;

  /// 加载 [thumbnailUrl] 时传给 [CachedNetworkImage.httpHeaders]，与套图列表一致。
  final Map<String, String> thumbnailHttpHeaders;
  final PicSetDownloadProgress progress;
  final DateTime createdAt;
  final DateTime? parseStartedAt;
  final DateTime? parseFinishedAt;
  final DateTime? completedAt;
  final String? lastErrorMessage;
  final List<PicSetDownloadFailureDetail> failureDetails;

  /// 相对 [path_provider] 的「应用文档目录」的路径（`path` 包语义，随平台分隔符变化）。
  ///
  /// iOS 每次安装后容器 UUID 会变，但 `getApplicationDocumentsDirectory()` 会指向新沙盒下的
  /// Documents；用本字段与当前文档目录拼接即可得到套图目录的绝对路径。
  final String localDirRelativeToApplicationDocuments;

  factory PicSetDownloadRecord.initialForEnqueue({
    required PicSetDownloadQueueTask task,
    required String localDirRelativeToApplicationDocuments,
  }) {
    final PicContent c = task.content;
    return PicSetDownloadRecord(
      id: task.id,
      contentHref: c.href,
      title: c.title,
      thumbnailUrl: c.thumbnail,
      entryDetailHref: c.href,
      host: PicHostSnapshot.fromHost(task.host),
      status: PicSetDownloadTaskStatus.queued,
      progress: const PicSetDownloadProgress(),
      createdAt: DateTime.now(),
      localDirRelativeToApplicationDocuments:
          localDirRelativeToApplicationDocuments,
      thumbnailHttpHeaders: Map<String, String>.unmodifiable(
        buildGalleryListImageHeaders(task.host),
      ),
    );
  }

  PicSetDownloadRecord copyWith({
    String? id,
    String? contentHref,
    String? title,
    String? thumbnailUrl,
    String? entryDetailHref,
    PicHostSnapshot? host,
    PicSetDownloadTaskStatus? status,
    PicSetDownloadProgress? progress,
    DateTime? createdAt,
    DateTime? parseStartedAt,
    DateTime? parseFinishedAt,
    DateTime? completedAt,
    String? lastErrorMessage,
    List<PicSetDownloadFailureDetail>? failureDetails,
    String? localDirRelativeToApplicationDocuments,
    Map<String, String>? thumbnailHttpHeaders,
  }) {
    return PicSetDownloadRecord(
      id: id ?? this.id,
      contentHref: contentHref ?? this.contentHref,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      entryDetailHref: entryDetailHref ?? this.entryDetailHref,
      host: host ?? this.host,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      parseStartedAt: parseStartedAt ?? this.parseStartedAt,
      parseFinishedAt: parseFinishedAt ?? this.parseFinishedAt,
      completedAt: completedAt ?? this.completedAt,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
      failureDetails: List<PicSetDownloadFailureDetail>.unmodifiable(
        failureDetails ?? this.failureDetails,
      ),
      localDirRelativeToApplicationDocuments:
          localDirRelativeToApplicationDocuments ??
          this.localDirRelativeToApplicationDocuments,
      thumbnailHttpHeaders: thumbnailHttpHeaders != null
          ? Map<String, String>.unmodifiable(thumbnailHttpHeaders)
          : this.thumbnailHttpHeaders,
    );
  }

  /// 与套图 cell 的 [PicContent] 对齐，用于跳转详情等。
  PicContent toPicContent({bool? isDownloaded}) {
    return PicContent(
      title: title,
      href: contentHref,
      thumbnail: thumbnailUrl,
      isDownloaded: isDownloaded,
    );
  }

  /// 冷启动恢复：已有库行时构造队列 A 任务，保留 [id] 且不再调用 [PicSetDownloadRecordStore.registerEnqueued]。
  ///
  /// [replaceExistingImageFiles] 未持久化，恢复时固定为 `false`（与默认下载一致）。
  PicSetDownloadQueueTask toResumeQueueTask() {
    return PicSetDownloadQueueTask(
      id: id,
      content: toPicContent(),
      host: host.toLoosePicHost(),
      replaceExistingImageFiles: false,
      recordRegistered: Completer<void>()..complete(),
    );
  }

  /// 失败套图在 UI 触发「重新下载」：沿用同一 [id] 与库行，可选覆盖本地已存在图片。
  PicSetDownloadQueueTask toRetryQueueTask({
    bool replaceExistingImageFiles = true,
  }) {
    return PicSetDownloadQueueTask(
      id: id,
      content: toPicContent(),
      host: host.toLoosePicHost(),
      replaceExistingImageFiles: replaceExistingImageFiles,
      recordRegistered: Completer<void>()..complete(),
    );
  }

  /// 进程被杀后冷启动：将非终态任务恢复为「排队」，清空进度与时间戳，保留身份与目录字段。
  PicSetDownloadRecord resetToQueuedPreservingIdentity() {
    return PicSetDownloadRecord(
      id: id,
      contentHref: contentHref,
      title: title,
      thumbnailUrl: thumbnailUrl,
      entryDetailHref: entryDetailHref,
      host: host,
      status: PicSetDownloadTaskStatus.queued,
      thumbnailHttpHeaders: thumbnailHttpHeaders,
      progress: const PicSetDownloadProgress(),
      createdAt: createdAt,
      parseStartedAt: null,
      parseFinishedAt: null,
      completedAt: null,
      lastErrorMessage: null,
      failureDetails: const <PicSetDownloadFailureDetail>[],
      localDirRelativeToApplicationDocuments:
          localDirRelativeToApplicationDocuments,
    );
  }
}
