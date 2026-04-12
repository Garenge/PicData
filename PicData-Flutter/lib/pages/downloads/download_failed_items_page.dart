import 'package:flutter/material.dart';

import 'package:pic_data/debug/page_backdoor.dart';
import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/services/pic_download_module.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';

const String _logCtx =
    'PicData-Flutter/lib/pages/downloads/download_failed_items_page.dart';

/// 失败项列表与重试： [recordId] 为 null 时汇总全部失败套图；指定时仅展示该套图一组。
class DownloadFailedItemsPage extends StatefulWidget {
  const DownloadFailedItemsPage({super.key, this.recordId});

  /// 为 null：全部失败组；非 null：仅该下载记录下的失败项。
  final String? recordId;

  @override
  State<DownloadFailedItemsPage> createState() =>
      _DownloadFailedItemsPageState();
}

class _DownloadFailedItemsPageState extends State<DownloadFailedItemsPage> {
  final Set<String> _inFlightKeys = <String>{};
  final Set<String> _groupRetryingRecordIds = <String>{};

  bool get _singleRecordMode => widget.recordId != null;

  static String _itemKey(String recordId, PicSetDownloadFailureDetail d) =>
      '$recordId|${d.identityKey}';

  List<PicSetDownloadRecord> _failedGroupsAll() {
    return PicSetDownloadRecordStore.instance.records
        .where(
          (PicSetDownloadRecord r) =>
              r.status == PicSetDownloadTaskStatus.failed &&
              r.failureDetails.isNotEmpty,
        )
        .toList();
  }

  /// 单套模式：与原先单页一致，只要有失败明细就展示（不要求 status 仍为 failed）。
  List<PicSetDownloadRecord> _groupsForDisplay() {
    if (widget.recordId != null) {
      final PicSetDownloadRecord? r =
          PicSetDownloadRecordStore.instance.tryGet(widget.recordId!);
      if (r == null || r.failureDetails.isEmpty) {
        return <PicSetDownloadRecord>[];
      }
      return <PicSetDownloadRecord>[r];
    }
    return _failedGroupsAll();
  }

  int _totalFailureCount(List<PicSetDownloadRecord> groups) {
    var n = 0;
    for (final PicSetDownloadRecord r in groups) {
      n += r.failureDetails.length;
    }
    return n;
  }

  Future<void> _retryOne(
    String recordId,
    PicSetDownloadFailureDetail detail,
  ) async {
    final String k = _itemKey(recordId, detail);
    if (_inFlightKeys.contains(k) || _groupRetryingRecordIds.contains(recordId)) {
      return;
    }
    final PicSetDownloadRecord? record =
        PicSetDownloadRecordStore.instance.tryGet(recordId);
    if (record == null) {
      return;
    }
    setState(() => _inFlightKeys.add(k));
    final PicSingleImageRetryResult result = await PicDownloadModule.instance
        .retryFailedImage(record: record, detail: detail);
    PicSetDownloadRecordStore.instance.applyFailureRetryResult(
      record.id,
      target: detail,
      success: result.success,
      failureReason: result.failureReason,
    );
    if (!mounted) {
      return;
    }
    setState(() => _inFlightKeys.remove(k));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? '重试成功：${detail.fileName}'
              : '重试失败：${result.failureReason ?? 'unknown'}',
        ),
      ),
    );
  }

  Future<void> _retryGroup(String recordId) async {
    if (_groupRetryingRecordIds.contains(recordId)) {
      return;
    }
    final PicSetDownloadRecord? start =
        PicSetDownloadRecordStore.instance.tryGet(recordId);
    if (start == null || start.failureDetails.isEmpty) {
      return;
    }
    final List<PicSetDownloadFailureDetail> batch =
        List<PicSetDownloadFailureDetail>.from(start.failureDetails);
    setState(() => _groupRetryingRecordIds.add(recordId));
    var successCount = 0;
    var failCount = 0;
    try {
      for (final PicSetDownloadFailureDetail detail in batch) {
        if (!mounted) {
          break;
        }
        final PicSetDownloadRecord? current =
            PicSetDownloadRecordStore.instance.tryGet(recordId);
        if (current == null) {
          break;
        }
        final String k = _itemKey(recordId, detail);
        setState(() => _inFlightKeys.add(k));
        final PicSingleImageRetryResult result = await PicDownloadModule.instance
            .retryFailedImage(record: current, detail: detail);
        PicSetDownloadRecordStore.instance.applyFailureRetryResult(
          current.id,
          target: detail,
          success: result.success,
          failureReason: result.failureReason,
        );
        if (result.success) {
          successCount++;
        } else {
          failCount++;
        }
        if (!mounted) {
          break;
        }
        setState(() => _inFlightKeys.remove(k));
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('$_logCtx#_retryGroup: recordId=$recordId error=$e');
      // ignore: avoid_print
      print('  stack=$st');
    } finally {
      if (mounted) {
        setState(() => _groupRetryingRecordIds.remove(recordId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _singleRecordMode
                  ? '批量重试完成：成功 $successCount，失败 $failCount'
                  : '本组批量重试完成：成功 $successCount，失败 $failCount',
            ),
          ),
        );
      }
    }
  }

  List<Widget> _sliversForOneGroup(
    PicSetDownloadRecord record,
    bool groupRetrying,
  ) {
    return <Widget>[
      SliverToBoxAdapter(
        child: _GroupHeader(
          record: record,
          groupRetrying: groupRetrying,
          onRetryGroup: () => _retryGroup(record.id),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            final PicSetDownloadFailureDetail item = record.failureDetails[index];
            final String k = _itemKey(record.id, item);
            final bool busy = _inFlightKeys.contains(k);
            final bool groupBusy = _groupRetryingRecordIds.contains(record.id);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (index > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text('#${item.sequence} ${item.fileName}'),
                  subtitle: Text(
                    '原因: ${item.reason}\nURL: ${item.imageUrl}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: groupBusy
                              ? null
                              : () => _retryOne(record.id, item),
                          child: const Text('重试'),
                        ),
                ),
              ],
            );
          },
          childCount: record.failureDetails.length,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String? rid = widget.recordId;
    final bool groupBusySingle =
        rid != null && _groupRetryingRecordIds.contains(rid);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => debugPrintPageBackdoorInfo(
            className: 'DownloadFailedItemsPage',
            filePath: _logCtx,
          ),
          child: Text(_singleRecordMode ? '失败项重试' : '全部失败项'),
        ),
        actions: [
          if (_singleRecordMode && rid != null)
            IconButton(
              tooltip: groupBusySingle ? '重试中' : '重试全部失败项',
              onPressed: groupBusySingle ? null : () => _retryGroup(rid),
              icon: groupBusySingle
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: PicSetDownloadRecordStore.instance,
        builder: (BuildContext context, Widget? _) {
          if (_singleRecordMode && rid != null) {
            final PicSetDownloadRecord? exists =
                PicSetDownloadRecordStore.instance.tryGet(rid);
            if (exists == null) {
              return const Center(child: Text('记录不存在或已删除'));
            }
          }

          final List<PicSetDownloadRecord> groups = _groupsForDisplay();
          if (groups.isEmpty) {
            return Center(
              child: Text(
                _singleRecordMode ? '没有失败项，已全部处理完成' : '当前没有失败项',
              ),
            );
          }

          final int total = _totalFailureCount(groups);
          final String summaryText = _singleRecordMode
              ? '套图：${groups.first.title}\n失败项：$total'
              : '共 $total 张失败 · ${groups.length} 套图';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  summaryText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CustomScrollView(
                  slivers: <Widget>[
                    for (var gi = 0; gi < groups.length; gi++) ...<Widget>[
                      if (gi > 0)
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      ..._sliversForOneGroup(
                        groups[gi],
                        _groupRetryingRecordIds.contains(groups[gi].id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.record,
    required this.groupRetrying,
    required this.onRetryGroup,
  });

  final PicSetDownloadRecord record;
  final bool groupRetrying;
  final VoidCallback onRetryGroup;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    record.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.failureDetails.length} 张失败',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            groupRetrying
                ? const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: onRetryGroup,
                    child: const Text('重试本组'),
                  ),
          ],
        ),
      ),
    );
  }
}
