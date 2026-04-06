import 'package:flutter/material.dart';
import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:pic_data/services/pic_download_module.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';

class DownloadFailedItemsPage extends StatefulWidget {
  const DownloadFailedItemsPage({super.key, required this.recordId});

  final String recordId;

  @override
  State<DownloadFailedItemsPage> createState() =>
      _DownloadFailedItemsPageState();
}

class _DownloadFailedItemsPageState extends State<DownloadFailedItemsPage> {
  final Set<String> _inFlightKeys = <String>{};
  bool _retryAllRunning = false;

  PicSetDownloadRecord? get _record =>
      PicSetDownloadRecordStore.instance.tryGet(widget.recordId);

  Future<void> _retryOne(PicSetDownloadFailureDetail detail) async {
    final PicSetDownloadRecord? record = _record;
    if (record == null) {
      return;
    }
    if (_inFlightKeys.contains(detail.identityKey)) {
      return;
    }
    setState(() {
      _inFlightKeys.add(detail.identityKey);
    });
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
    setState(() {
      _inFlightKeys.remove(detail.identityKey);
    });
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

  Future<void> _retryAll() async {
    final PicSetDownloadRecord? record = _record;
    if (record == null || record.failureDetails.isEmpty || _retryAllRunning) {
      return;
    }
    setState(() {
      _retryAllRunning = true;
    });
    int successCount = 0;
    int failCount = 0;
    final List<PicSetDownloadFailureDetail> batch =
        List<PicSetDownloadFailureDetail>.from(record.failureDetails);
    for (final PicSetDownloadFailureDetail detail in batch) {
      if (!mounted) {
        break;
      }
      setState(() {
        _inFlightKeys.add(detail.identityKey);
      });
      final PicSetDownloadRecord? current = _record;
      if (current == null) {
        break;
      }
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
      setState(() {
        _inFlightKeys.remove(detail.identityKey);
      });
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _retryAllRunning = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('批量重试完成：成功 $successCount，失败 $failCount')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('失败项重试'),
        actions: [
          IconButton(
            tooltip: _retryAllRunning ? '重试中' : '重试全部失败项',
            onPressed: _retryAllRunning ? null : _retryAll,
            icon: _retryAllRunning
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
          final PicSetDownloadRecord? record = _record;
          if (record == null) {
            return const Center(child: Text('记录不存在或已删除'));
          }
          final List<PicSetDownloadFailureDetail> failures =
              record.failureDetails;
          if (failures.isEmpty) {
            return const Center(child: Text('没有失败项，已全部处理完成'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '套图：${record.title}\n失败项：${failures.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: failures.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final PicSetDownloadFailureDetail item = failures[index];
                    final bool busy = _inFlightKeys.contains(item.identityKey);
                    return ListTile(
                      dense: true,
                      title: Text('#${item.sequence} ${item.fileName}'),
                      subtitle: Text(
                        '原因: ${item.reason}\nURL: ${item.imageUrl}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: _retryAllRunning
                                  ? null
                                  : () {
                                      _retryOne(item);
                                    },
                              child: const Text('重试'),
                            ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
