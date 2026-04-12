import 'package:flutter/material.dart';

import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/services/pic_download_module.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';

const String _logCtx =
    'PicData-Flutter/lib/pages/downloads/all_failed_download_items_page.dart';

/// 汇总所有失败套图中的 [PicSetDownloadFailureDetail]，按套图分组；组头可批量重试。
class AllFailedDownloadItemsPage extends StatefulWidget {
  const AllFailedDownloadItemsPage({super.key});

  @override
  State<AllFailedDownloadItemsPage> createState() =>
      _AllFailedDownloadItemsPageState();
}

class _AllFailedDownloadItemsPageState extends State<AllFailedDownloadItemsPage> {
  final Set<String> _inFlightKeys = <String>{};
  final Set<String> _groupRetryingRecordIds = <String>{};

  static String _itemKey(String recordId, PicSetDownloadFailureDetail d) =>
      '$recordId|${d.identityKey}';

  List<PicSetDownloadRecord> _failedGroups() {
    return PicSetDownloadRecordStore.instance.records
        .where(
          (PicSetDownloadRecord r) =>
              r.status == PicSetDownloadTaskStatus.failed &&
              r.failureDetails.isNotEmpty,
        )
        .toList();
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
            content: Text('本组批量重试完成：成功 $successCount，失败 $failCount'),
          ),
        );
      }
    }
  }

  /// 每组独立 [SliverList]，避免长列表单一大 delegate；[record] 在当次 build 内固定引用。
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
    return Scaffold(
      appBar: AppBar(title: const Text('全部失败项')),
      body: ListenableBuilder(
        listenable: PicSetDownloadRecordStore.instance,
        builder: (BuildContext context, Widget? _) {
          final List<PicSetDownloadRecord> groups = _failedGroups();
          final int total = _totalFailureCount(groups);
          if (groups.isEmpty) {
            return const Center(child: Text('当前没有失败项'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  '共 $total 张失败 · ${groups.length} 套图',
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
            if (groupRetrying)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton(
                onPressed: onRetryGroup,
                child: const Text('重试本组'),
              ),
          ],
        ),
      ),
    );
  }
}
