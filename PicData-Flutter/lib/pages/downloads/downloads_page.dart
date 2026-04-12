import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/pages/downloads/all_failed_download_items_page.dart';
import 'package:pic_data/pages/downloads/download_failed_items_page.dart';
import 'package:pic_data/pages/files/open_download_record_local_folder.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/services/open_local_folder.dart';
import 'package:pic_data/services/pic_download_module.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';
import 'package:pic_data/utils/gallery_grid_layout.dart';
import 'package:pic_data/widgets/gallery_list_thumbnail.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, required this.refreshSignal});

  /// 与 [MainTabPage] 联动：每次切到「下载」Tab 时递增，触发从磁盘同步进度。
  final int refreshSignal;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProgress();
    });
  }

  @override
  void didUpdateWidget(covariant DownloadsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      _refreshProgress();
    }
  }

  Future<void> _refreshProgress() async {
    await PicSetDownloadRecordStore.instance.syncImageProgressFromDisk();
  }

  void _resumeDownloadsFromPause() {
    PicDownloadModule.instance.resumeDownloadsAfterUserPause();
    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已开始下载')),
    );
  }

  Future<void> _openDownloadsRootInSystem(BuildContext context) async {
    final path = await DownloadFileService.instance.getRootPath();
    if (!context.mounted) {
      return;
    }
    await openLocalFolderInSystem(context, path);
  }

  static int _crossAxisCountForLayout(BuildContext context, double maxWidth) {
    if (isCompactGalleryGrid(context)) {
      return 3;
    }
    const double itemWidth = 180;
    const double spacing = 12;
    return (maxWidth / (itemWidth + spacing)).floor().clamp(1, 6);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        PicSetDownloadRecordStore.instance,
        PicDownloadModule.instance.globalPauseNotifier,
      ]),
      builder: (BuildContext context, Widget? _) {
        final List<PicSetDownloadRecord> records =
            PicSetDownloadRecordStore.instance.records;
        final bool showResumeControl = PicDownloadModule.instance.isGloballyPaused ||
            records.any(
              (PicSetDownloadRecord r) =>
                  r.status == PicSetDownloadTaskStatus.paused,
            );
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => debugPrintPageBackdoorInfo(
                className: 'DownloadsPage',
                filePath: 'PicData-Flutter/lib/pages/downloads/downloads_page.dart',
              ),
              child: const Text('下载'),
            ),
            actions: [
              if (showResumeControl)
                TextButton(
                  onPressed: _resumeDownloadsFromPause,
                  child: const Text('开始下载'),
                ),
              IconButton(
                tooltip: '刷新进度',
                icon: const Icon(Icons.refresh),
                onPressed: _refreshProgress,
              ),
              IconButton(
                tooltip: supportsOpenLocalFolderInSystem
                    ? '打开下载文件夹'
                    : '打开本地文件夹（仅桌面系统）',
                icon: const Icon(Icons.folder_open_outlined),
                onPressed: () => _openDownloadsRootInSystem(context),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int crossAxisCount =
                  _DownloadsPageState._crossAxisCountForLayout(
                    context,
                    constraints.maxWidth,
                  );
              final compact = isCompactGalleryGrid(context);
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (records.isEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 8 : 16,
                        4,
                        compact ? 8 : 16,
                        12,
                      ),
                      child: Text(
                        '暂无下载记录',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  _DownloadStatusSection(
                    title: '未开始',
                    status: PicSetDownloadTaskStatus.queued,
                    records: records,
                    crossAxisCount: crossAxisCount,
                  ),
                  _DownloadStatusSection(
                    title: '已暂停',
                    status: PicSetDownloadTaskStatus.paused,
                    records: records,
                    crossAxisCount: crossAxisCount,
                  ),
                  _DownloadStatusSection(
                    title: '进行中',
                    status: PicSetDownloadTaskStatus.inProgress,
                    records: records,
                    crossAxisCount: crossAxisCount,
                  ),
                  _DownloadStatusSection(
                    title: '已完成',
                    status: PicSetDownloadTaskStatus.completed,
                    records: records,
                    crossAxisCount: crossAxisCount,
                  ),
                  _DownloadStatusSection(
                    title: '失败',
                    status: PicSetDownloadTaskStatus.failed,
                    records: records,
                    crossAxisCount: crossAxisCount,
                    titleTrailing: _failedSectionAllFailuresButton(context, records),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

Widget? _failedSectionAllFailuresButton(
  BuildContext context,
  List<PicSetDownloadRecord> records,
) {
  final int totalFailures = records
      .where(
        (PicSetDownloadRecord r) =>
            r.status == PicSetDownloadTaskStatus.failed,
      )
      .fold<int>(
        0,
        (int a, PicSetDownloadRecord r) => a + r.failureDetails.length,
      );
  if (totalFailures <= 0) {
    return null;
  }
  return IconButton(
    tooltip: '全部失败项（$totalFailures）',
    icon: const Icon(Icons.view_list_outlined),
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AllFailedDownloadItemsPage(),
        ),
      );
    },
  );
}

class _DownloadStatusSection extends StatelessWidget {
  const _DownloadStatusSection({
    required this.title,
    required this.status,
    required this.records,
    required this.crossAxisCount,
    this.titleTrailing,
  });

  final String title;
  final PicSetDownloadTaskStatus status;
  final List<PicSetDownloadRecord> records;
  final int crossAxisCount;

  /// 与 [ExpansionTile] 默认展开箭头同一行，位于箭头左侧（如「失败」汇总入口）。
  final Widget? titleTrailing;

  @override
  Widget build(BuildContext context) {
    final double gridSpacing = galleryGridSpacing(context);
    final List<PicSetDownloadRecord> filtered = records
        .where((PicSetDownloadRecord r) => r.status == status)
        .toList();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String countLabel = '${filtered.length} 项';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: titleTrailing == null
            ? Text(title)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(
                          countLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  titleTrailing!,
                ],
              ),
        subtitle: titleTrailing == null ? Text(countLabel) : null,
        children: [
          if (filtered.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCompactGalleryGrid(context) ? 8 : 16,
                0,
                isCompactGalleryGrid(context) ? 8 : 16,
                16,
              ),
              child: Text(
                '无',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: gridSpacing,
                  crossAxisSpacing: gridSpacing,
                  childAspectRatio: 3 / 4,
                ),
                itemBuilder: (BuildContext context, int index) {
                  return _DownloadRecordCell(record: filtered[index]);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DownloadRecordCell extends StatefulWidget {
  const _DownloadRecordCell({required this.record});

  final PicSetDownloadRecord record;

  @override
  State<_DownloadRecordCell> createState() => _DownloadRecordCellState();
}

class _DownloadRecordCellState extends State<_DownloadRecordCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final PicSetDownloadRecord record = widget.record;
    final Map<String, String> headers = record.thumbnailHttpHeaders;
    final Widget? progressBar = _downloadRecordProgressBar(context, record);

    return GestureDetector(
      onSecondaryTapUp: (TapUpDetails details) {
        _showDownloadRecordContextMenu(context, details.globalPosition, record);
      },
      onLongPress: () {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box == null) {
          return;
        }
        final Offset pos = box.localToGlobal(box.size.center(Offset.zero));
        _showDownloadRecordContextMenu(context, pos, record);
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: _hovered
              ? (Matrix4.identity()..scaleByDouble(1.02, 1.02, 1.02, 1))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Card(
            elevation: _hovered ? 8 : 2,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => pushFileBrowserForDownloadRecord(context, record),
              hoverColor: Colors.black.withValues(alpha: 0.02),
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GalleryListThumbnail(
                      imageUrl: record.thumbnailUrl,
                      headers: headers,
                      title: record.title,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          record.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusDetail(record),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (record.status == PicSetDownloadTaskStatus.failed &&
                            record.failureDetails.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => DownloadFailedItemsPage(
                                      recordId: record.id,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh, size: 14),
                              label: const Text('失败项重试'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                        if (progressBar != null) ...[
                          const SizedBox(height: 6),
                          progressBar,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showDownloadRecordContextMenu(
  BuildContext context,
  Offset globalPosition,
  PicSetDownloadRecord record,
) async {
  final OverlayState overlayState = Overlay.of(context);
  final RenderBox overlay =
      overlayState.context.findRenderObject()! as RenderBox;
  final RelativeRect position = RelativeRect.fromRect(
    Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
    Offset.zero & overlay.size,
  );
  final List<PopupMenuEntry<String>> menuItems = <PopupMenuEntry<String>>[
    if (record.status == PicSetDownloadTaskStatus.failed)
      const PopupMenuItem<String>(
        value: 'retry_download',
        child: Text('重新下载（覆盖已存在文件）'),
      ),
    const PopupMenuItem<String>(
      value: 'delete_record',
      child: Text('删除记录（保留文件）'),
    ),
    const PopupMenuItem<String>(
      value: 'delete_record_and_files',
      child: Text('删除记录和本地文件'),
    ),
  ];
  final String? action = await showMenu<String>(
    context: context,
    position: position,
    items: menuItems,
  );
  if (!context.mounted) {
    return;
  }
  if (action == 'retry_download') {
    await _retryFailedSetDownloadFromMenu(context, record);
    return;
  }
  if (action == 'delete_record') {
    await _confirmRemoveDownloadRecord(
      context,
      record,
      deleteLocalFiles: false,
    );
    return;
  }
  if (action == 'delete_record_and_files') {
    await _confirmRemoveDownloadRecord(context, record, deleteLocalFiles: true);
  }
}

Future<void> _retryFailedSetDownloadFromMenu(
  BuildContext context,
  PicSetDownloadRecord record,
) async {
  try {
    await PicDownloadModule.instance.retryFailedSetDownload(
      record,
      replaceExistingImageFiles: true,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已开始重新下载（已存在文件将被覆盖）')),
    );
  } catch (e, st) {
    // ignore: avoid_print
    print(
      'PicData-Flutter/lib/pages/downloads/downloads_page.dart#'
      '_retryFailedSetDownloadFromMenu: failed: $e',
    );
    // ignore: avoid_print
    print('  stack=$st');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('重新下载失败：$e')));
    }
  }
}

Future<void> _confirmRemoveDownloadRecord(
  BuildContext context,
  PicSetDownloadRecord record, {
  required bool deleteLocalFiles,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text(deleteLocalFiles ? '删除记录与文件' : '删除下载记录'),
        content: Text(
          deleteLocalFiles
              ? '确定删除「${record.title}」的记录，并永久删除本机该套图目录下的全部已下载文件？此操作不可恢复。'
              : '确定删除「${record.title}」的下载记录？本机已下载的文件夹与图片将保留。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(deleteLocalFiles ? '删除全部' : '删除记录'),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) {
    return;
  }
  try {
    await PicSetDownloadRecordStore.instance.removeRecord(
      record.id,
      deleteLocalFiles: deleteLocalFiles,
    );
  } catch (e, st) {
    // ignore: avoid_print
    print(
      'PicData-Flutter/lib/pages/downloads/downloads_page.dart#_confirmRemoveDownloadRecord: '
      'removeRecord failed: $e',
    );
    // ignore: avoid_print
    print('  stack=$st');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
    }
  }
}

/// 排队/已完成不展示；进行中解析阶段为不确定进度，拉图阶段为确定进度；失败且已知总数时展示冻结进度。
Widget? _downloadRecordProgressBar(
  BuildContext context,
  PicSetDownloadRecord record,
) {
  final PicSetDownloadProgress p = record.progress;
  final ColorScheme cs = Theme.of(context).colorScheme;

  switch (record.status) {
    case PicSetDownloadTaskStatus.queued:
    case PicSetDownloadTaskStatus.completed:
      return null;
    case PicSetDownloadTaskStatus.paused:
      if (!p.parseFinished) {
        return null;
      }
      final int? pausedTotal = p.plannedImageTotal;
      if (pausedTotal == null || pausedTotal <= 0) {
        return null;
      }
      final double pv = (p.imageJobsFinished / pausedTotal).clamp(0.0, 1.0);
      return _downloadLinearBar(context, value: pv, color: cs.outline);
    case PicSetDownloadTaskStatus.failed:
      final int? total = p.plannedImageTotal;
      if (!p.parseFinished || total == null || total <= 0) {
        return null;
      }
      final double v = (p.imageJobsFinished / total).clamp(0.0, 1.0);
      return _downloadLinearBar(context, value: v, color: cs.outline);
    case PicSetDownloadTaskStatus.inProgress:
      if (!p.parseFinished) {
        return _downloadLinearBar(context, indeterminate: true);
      }
      final int total = p.plannedImageTotal ?? 0;
      if (total <= 0) {
        return null;
      }
      final double v = (p.imageJobsFinished / total).clamp(0.0, 1.0);
      return _downloadLinearBar(context, value: v);
  }
}

Widget _downloadLinearBar(
  BuildContext context, {
  bool indeterminate = false,
  double? value,
  Color? color,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  final Color track = cs.surfaceContainerHighest.withValues(alpha: 0.55);
  final Color fill = color ?? cs.primary;

  return ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: SizedBox(
      height: 3,
      child: indeterminate
          ? LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: track,
              color: fill,
            )
          : LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: track,
              color: fill,
            ),
    ),
  );
}

String _statusDetail(PicSetDownloadRecord record) {
  final PicSetDownloadProgress p = record.progress;
  switch (record.status) {
    case PicSetDownloadTaskStatus.queued:
      return '排队中';
    case PicSetDownloadTaskStatus.paused:
      if (!p.parseFinished) {
        return '已暂停 · 解析 ${p.parsePagesLoaded} 页';
      }
      final int pt = p.plannedImageTotal ?? 0;
      return pt > 0
          ? '已暂停 · 进度 ${p.imageJobsFinished}/$pt'
          : '已暂停';
    case PicSetDownloadTaskStatus.inProgress:
      if (!p.parseFinished) {
        return '解析 ${p.parsePagesLoaded} 页 · 已发现 ${p.parseUniqueImagesSoFar} 张';
      }
      final int t = p.plannedImageTotal ?? 0;
      return '下载 ${p.imageJobsFinished}/$t';
    case PicSetDownloadTaskStatus.completed:
      final int n = p.plannedImageTotal ?? p.imageJobsSucceeded;
      return n > 0 ? '共 $n 张' : '已完成';
    case PicSetDownloadTaskStatus.failed:
      if (record.failureDetails.isNotEmpty) {
        return '失败 ${record.failureDetails.length} 张 · 支持重试';
      }
      return record.lastErrorMessage ?? '失败';
  }
}
