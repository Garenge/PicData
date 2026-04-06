import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/pages/files/open_download_record_local_folder.dart';
import 'package:pic_data/services/download_file_service.dart';
import 'package:pic_data/services/open_local_folder.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';
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

  Future<void> _openDownloadsRootInSystem(BuildContext context) async {
    final path = await DownloadFileService.instance.getRootPath();
    if (!context.mounted) {
      return;
    }
    await openLocalFolderInSystem(context, path);
  }

  static int _crossAxisCountForWidth(double maxWidth) {
    const double itemWidth = 180;
    const double spacing = 12;
    return (maxWidth / (itemWidth + spacing)).floor().clamp(1, 6);
  }

  @override
  Widget build(BuildContext context) {
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
      body: ListenableBuilder(
        listenable: PicSetDownloadRecordStore.instance,
        builder: (BuildContext context, Widget? _) {
          final List<PicSetDownloadRecord> records =
              PicSetDownloadRecordStore.instance.records;
          if (records.isEmpty) {
            return Center(
              child: Text(
                '暂无下载记录',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int crossAxisCount =
                  _DownloadsPageState._crossAxisCountForWidth(
                constraints.maxWidth,
              );
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DownloadStatusSection(
                    title: '未开始',
                    status: PicSetDownloadTaskStatus.queued,
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
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DownloadStatusSection extends StatelessWidget {
  const _DownloadStatusSection({
    required this.title,
    required this.status,
    required this.records,
    required this.crossAxisCount,
  });

  final String title;
  final PicSetDownloadTaskStatus status;
  final List<PicSetDownloadRecord> records;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final List<PicSetDownloadRecord> filtered =
        records.where((PicSetDownloadRecord r) => r.status == status).toList();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(title),
        subtitle: Text('${filtered.length} 项'),
        children: [
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
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

    return MouseRegion(
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _statusDetail(PicSetDownloadRecord record) {
  final PicSetDownloadProgress p = record.progress;
  switch (record.status) {
    case PicSetDownloadTaskStatus.queued:
      return '排队中';
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
      return record.lastErrorMessage ?? '失败';
  }
}
