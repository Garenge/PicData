import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/models/pic_set_download_record.dart';
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
  static const double _failedSelectionTriggerDistance = 12;
  static const int _primaryPointerButton = 1;

  final Set<String> _selectedFailedRecordIds = <String>{};
  final GlobalKey _failedSectionKey = GlobalKey();
  final Map<String, GlobalKey> _failedRecordKeys = <String, GlobalKey>{};
  Offset? _failedSelectionStart;
  Offset? _failedSelectionCurrent;
  Rect? _failedSelectionRect;
  bool _failedSelectionActive = false;

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

  void _syncFailedSelection(List<PicSetDownloadRecord> records) {
    final Set<String> failedIds = records
        .where(
          (PicSetDownloadRecord r) =>
              r.status == PicSetDownloadTaskStatus.failed,
        )
        .map((PicSetDownloadRecord r) => r.id)
        .toSet();
    _selectedFailedRecordIds.removeWhere(
      (String id) => !failedIds.contains(id),
    );
    if (_selectedFailedRecordIds.isEmpty && _failedSelectionStart == null) {
      _clearFailedSelectionBox();
    }
    _failedRecordKeys.removeWhere((String id, _) => !failedIds.contains(id));
  }

  void _toggleFailedRecordSelection(String recordId) {
    setState(() {
      if (_selectedFailedRecordIds.contains(recordId)) {
        _selectedFailedRecordIds.remove(recordId);
      } else {
        _selectedFailedRecordIds.add(recordId);
      }
    });
  }

  GlobalKey _failedRecordKey(String recordId) {
    return _failedRecordKeys.putIfAbsent(recordId, GlobalKey.new);
  }

  bool _isPrimaryMousePointer(PointerEvent event) {
    return _supportsFailedSelectionPointerKind(event.kind) &&
        (event.buttons & _primaryPointerButton) != 0;
  }

  bool _supportsFailedSelectionPointerKind(PointerDeviceKind kind) {
    return kind == PointerDeviceKind.mouse ||
        kind == PointerDeviceKind.trackpad;
  }

  bool _containsGlobalPosition(GlobalKey key, Offset globalPosition) {
    final BuildContext? keyContext = key.currentContext;
    if (keyContext == null) {
      return false;
    }
    final RenderBox? box = keyContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return false;
    }
    final Offset local = box.globalToLocal(globalPosition);
    return (Offset.zero & box.size).contains(local);
  }

  Offset? _pageLocalFromGlobal(Offset globalPosition) {
    final RenderBox? pageBox = context.findRenderObject() as RenderBox?;
    return pageBox?.globalToLocal(globalPosition);
  }

  void _startFailedBoxSelection(PointerDownEvent event) {
    if (!_containsGlobalPosition(_failedSectionKey, event.position)) {
      return;
    }
    final Offset? start = _pageLocalFromGlobal(event.position);
    if (start == null) {
      return;
    }
    setState(() {
      _failedSelectionStart = start;
      _failedSelectionCurrent = start;
      _failedSelectionRect = null;
      _failedSelectionActive = false;
    });
  }

  void _updateFailedBoxSelection(PointerMoveEvent event) {
    final Offset? start = _failedSelectionStart;
    if (start == null) {
      return;
    }
    final Offset? pageLocal = _pageLocalFromGlobal(event.position);
    if (pageLocal == null) {
      return;
    }
    final Offset current = pageLocal;
    final Rect rect = Rect.fromPoints(start, current);
    final bool active =
        _failedSelectionActive ||
        (current - start).distance >= _failedSelectionTriggerDistance;
    if (!active) {
      setState(() {
        _failedSelectionCurrent = current;
        _failedSelectionRect = null;
      });
      return;
    }
    final Set<String> selectedIds = _failedRecordIdsInSelectionRect(rect);
    setState(() {
      _failedSelectionCurrent = current;
      _failedSelectionRect = rect;
      _failedSelectionActive = true;
      _selectedFailedRecordIds
        ..clear()
        ..addAll(selectedIds);
    });
  }

  void _finishFailedBoxSelection() {
    if (_failedSelectionStart == null) {
      return;
    }
    if (!_failedSelectionActive) {
      setState(() => _clearFailedSelectionBox());
      return;
    }
    setState(() {
      _clearFailedSelectionBox();
    });
  }

  void _clearFailedSelectionBox() {
    _failedSelectionStart = null;
    _failedSelectionCurrent = null;
    _failedSelectionRect = null;
    _failedSelectionActive = false;
  }

  Rect? _failedRecordRectInPage(GlobalKey key) {
    final RenderBox? pageBox = context.findRenderObject() as RenderBox?;
    if (pageBox == null) {
      return null;
    }
    final BuildContext? keyContext = key.currentContext;
    if (keyContext == null) {
      return null;
    }
    final RenderBox? box = keyContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    final Offset globalTopLeft = box.localToGlobal(Offset.zero);
    final Offset localTopLeft = pageBox.globalToLocal(globalTopLeft);
    return localTopLeft & box.size;
  }

  Set<String> _failedRecordIdsInSelectionRect(Rect selectionRect) {
    final Set<String> selectedIds = <String>{};
    _failedRecordKeys.forEach((String recordId, GlobalKey key) {
      final Rect? itemRect = _failedRecordRectInPage(key);
      if (itemRect == null) {
        return;
      }
      if (selectionRect.overlaps(itemRect)) {
        selectedIds.add(recordId);
      }
    });
    return selectedIds;
  }

  bool _isMeaningfulFailedSelectionDrag() {
    final Offset? start = _failedSelectionStart;
    final Offset? current = _failedSelectionCurrent;
    if (start == null || current == null) {
      return false;
    }
    return (current - start).distance >= _failedSelectionTriggerDistance;
  }

  void _handlePagePointerDown(PointerDownEvent event) {
    if (!_isPrimaryMousePointer(event)) {
      return;
    }
    _startFailedBoxSelection(event);
  }

  void _handlePagePointerMove(PointerMoveEvent event) {
    if (!_isPrimaryMousePointer(event)) {
      return;
    }
    _updateFailedBoxSelection(event);
  }

  void _handlePagePointerEnd(PointerEvent event) {
    if (!_supportsFailedSelectionPointerKind(event.kind)) {
      return;
    }
    _finishFailedBoxSelection();
  }

  void _clearFailedSelection() {
    if (_selectedFailedRecordIds.isEmpty) {
      return;
    }
    setState(() {
      _selectedFailedRecordIds.clear();
      _clearFailedSelectionBox();
    });
  }

  void _toggleSelectAllFailed(List<PicSetDownloadRecord> records) {
    final Set<String> failedIds = records
        .where(
          (PicSetDownloadRecord r) =>
              r.status == PicSetDownloadTaskStatus.failed,
        )
        .map((PicSetDownloadRecord r) => r.id)
        .toSet();
    setState(() {
      if (_selectedFailedRecordIds.length == failedIds.length) {
        _selectedFailedRecordIds.clear();
      } else {
        _selectedFailedRecordIds
          ..clear()
          ..addAll(failedIds);
      }
    });
  }

  Future<void> _deleteSelectedFailedRecords(
    List<PicSetDownloadRecord> records,
  ) async {
    if (_selectedFailedRecordIds.isEmpty) {
      return;
    }
    final List<PicSetDownloadRecord> targets = records
        .where(
          (PicSetDownloadRecord r) =>
              r.status == PicSetDownloadTaskStatus.failed &&
              _selectedFailedRecordIds.contains(r.id),
        )
        .toList();
    if (targets.isEmpty) {
      _clearFailedSelection();
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('批量删除失败记录'),
          content: Text('确定删除选中的 ${targets.length} 条失败记录吗？本机已下载文件会保留。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除记录'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      for (final PicSetDownloadRecord record in targets) {
        await PicSetDownloadRecordStore.instance.removeRecord(record.id);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedFailedRecordIds.clear();
        _clearFailedSelectionBox();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除 ${targets.length} 条失败记录')));
    } catch (e, st) {
      // ignore: avoid_print
      print(
        'PicData-Flutter/lib/pages/downloads/downloads_page.dart#'
        '_deleteSelectedFailedRecords: failed: $e',
      );
      // ignore: avoid_print
      print('  stack=$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('批量删除失败：$e')));
      }
    }
  }

  void _resumeDownloadsFromPause() {
    PicDownloadModule.instance.resumeDownloadsAfterUserPause();
    if (!mounted) {
      return;
    }
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已开始下载')));
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
        _syncFailedSelection(records);
        final bool showResumeControl =
            PicDownloadModule.instance.isGloballyPaused ||
            records.any(
              (PicSetDownloadRecord r) =>
                  r.status == PicSetDownloadTaskStatus.paused,
            );
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => debugPrintPageBackdoorInfo(
                className: 'DownloadsPage',
                filePath:
                    'PicData-Flutter/lib/pages/downloads/downloads_page.dart',
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
              if (_selectedFailedRecordIds.isNotEmpty)
                IconButton(
                  tooltip: '取消失败项选择',
                  icon: const Icon(Icons.close),
                  onPressed: _clearFailedSelection,
                ),
              if (_selectedFailedRecordIds.isNotEmpty)
                IconButton(
                  tooltip: '删除选中的失败记录',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteSelectedFailedRecords(records),
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
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handlePagePointerDown,
                onPointerMove: _handlePagePointerMove,
                onPointerUp: _handlePagePointerEnd,
                onPointerCancel: _handlePagePointerEnd,
                child: Stack(
                  children: <Widget>[
                    ListView(
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                          key: _failedSectionKey,
                          title: '失败',
                          status: PicSetDownloadTaskStatus.failed,
                          records: records,
                          crossAxisCount: crossAxisCount,
                          selectionMode: _selectedFailedRecordIds.isNotEmpty,
                          selectedIds: _selectedFailedRecordIds,
                          keyForRecord: _failedRecordKey,
                          onToggleSelection: _toggleFailedRecordSelection,
                          selectionSummary: _selectedFailedRecordIds.isEmpty
                              ? null
                              : '已选 ${_selectedFailedRecordIds.length} 项',
                          titleTrailing: _failedSectionAllFailuresButton(
                            context,
                            records,
                          ),
                          footerActionBar: _selectedFailedRecordIds.isEmpty
                              ? null
                              : _buildFailedSelectionBar(records),
                        ),
                      ],
                    ),
                    if (_isMeaningfulFailedSelectionDrag() &&
                        _failedSelectionRect != null)
                      Positioned.fromRect(
                        rect: _failedSelectionRect!,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.10),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget? _buildFailedSelectionBar(List<PicSetDownloadRecord> records) {
    if (_selectedFailedRecordIds.isEmpty) {
      return null;
    }
    final int failedCount = records
        .where(
          (PicSetDownloadRecord r) =>
              r.status == PicSetDownloadTaskStatus.failed,
        )
        .length;
    if (failedCount <= 0) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: () => _toggleSelectAllFailed(records),
            icon: Icon(
              _selectedFailedRecordIds.length == failedCount
                  ? Icons.deselect_outlined
                  : Icons.select_all_outlined,
            ),
            label: Text(
              _selectedFailedRecordIds.length == failedCount ? '取消全选' : '全选失败项',
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _selectedFailedRecordIds.isEmpty
                ? null
                : () => _deleteSelectedFailedRecords(records),
            icon: const Icon(Icons.delete_outline),
            label: Text(
              _selectedFailedRecordIds.isEmpty
                  ? '删除失败记录'
                  : '删除 ${_selectedFailedRecordIds.length} 项',
            ),
          ),
        ],
      ),
    );
  }
}

Widget? _failedSectionAllFailuresButton(
  BuildContext context,
  List<PicSetDownloadRecord> records,
) {
  final int totalFailures = records
      .where(
        (PicSetDownloadRecord r) => r.status == PicSetDownloadTaskStatus.failed,
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
          builder: (_) => const DownloadFailedItemsPage(),
        ),
      );
    },
  );
}

class _DownloadStatusSection extends StatelessWidget {
  const _DownloadStatusSection({
    super.key,
    required this.title,
    required this.status,
    required this.records,
    required this.crossAxisCount,
    this.titleTrailing,
    this.selectionMode = false,
    this.selectedIds = const <String>{},
    this.keyForRecord,
    this.onToggleSelection,
    this.selectionSummary,
    this.footerActionBar,
  });

  final String title;
  final PicSetDownloadTaskStatus status;
  final List<PicSetDownloadRecord> records;
  final int crossAxisCount;

  /// 与 [ExpansionTile] 默认展开箭头同一行，位于箭头左侧（如「失败」汇总入口）。
  final Widget? titleTrailing;
  final bool selectionMode;
  final Set<String> selectedIds;
  final GlobalKey Function(String recordId)? keyForRecord;
  final ValueChanged<String>? onToggleSelection;
  final String? selectionSummary;
  final Widget? footerActionBar;

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
          if (selectionSummary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectionSummary!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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
                  final PicSetDownloadRecord record = filtered[index];
                  return _DownloadRecordCell(
                    key: keyForRecord?.call(record.id),
                    record: record,
                    selectionMode: selectionMode,
                    selected: selectedIds.contains(record.id),
                    onToggleSelection: onToggleSelection == null
                        ? null
                        : () => onToggleSelection!(record.id),
                  );
                },
              ),
            ),
          ?footerActionBar,
        ],
      ),
    );
  }
}

class _DownloadRecordCell extends StatefulWidget {
  const _DownloadRecordCell({
    super.key,
    required this.record,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelection,
  });

  final PicSetDownloadRecord record;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelection;

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
            color: widget.selected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.55)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: widget.selected
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.4,
                    )
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: widget.selectionMode
                  ? widget.onToggleSelection
                  : () => pushFileBrowserForDownloadRecord(context, record),
              hoverColor: Colors.black.withValues(alpha: 0.02),
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.selectionMode || widget.selected)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Checkbox(
                          value: widget.selected,
                          onChanged: (_) => widget.onToggleSelection?.call(),
                        ),
                      ),
                    ),
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
    if (record.status == PicSetDownloadTaskStatus.inProgress)
      const PopupMenuItem<String>(
        value: 'stop_and_delete',
        child: Text('停止并删除任务'),
      ),
    if (record.status.canRedownload)
      const PopupMenuItem<String>(
        value: 'redownload',
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
  if (action == 'redownload') {
    await _redownloadSetFromMenu(context, record);
    return;
  }
  if (action == 'stop_and_delete') {
    await _confirmStopAndDeleteRunningTask(context, record);
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

Future<void> _confirmStopAndDeleteRunningTask(
  BuildContext context,
  PicSetDownloadRecord record,
) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: const Text('停止并删除任务'),
        content: Text(
          '确定停止「${record.title}」当前套图下的所有下载任务，并删除这条下载记录吗？已下载到本机的文件会保留。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('停止并删除'),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) {
    return;
  }
  try {
    await PicDownloadModule.instance.cancelAndRemoveSetTask(record.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已停止并删除任务')));
  } catch (e, st) {
    // ignore: avoid_print
    print(
      'PicData-Flutter/lib/pages/downloads/downloads_page.dart#'
      '_confirmStopAndDeleteRunningTask: failed: $e',
    );
    // ignore: avoid_print
    print('  stack=$st');
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('停止并删除失败：$e')));
    }
  }
}

Future<void> _redownloadSetFromMenu(
  BuildContext context,
  PicSetDownloadRecord record,
) async {
  try {
    await PicDownloadModule.instance.redownloadSet(
      record,
      replaceExistingImageFiles: true,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已开始重新下载（已存在文件将被覆盖）')));
  } catch (e, st) {
    // ignore: avoid_print
    print(
      'PicData-Flutter/lib/pages/downloads/downloads_page.dart#'
      '_redownloadSetFromMenu: failed: $e',
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
      return pt > 0 ? '已暂停 · 进度 ${p.imageJobsFinished}/$pt' : '已暂停';
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
