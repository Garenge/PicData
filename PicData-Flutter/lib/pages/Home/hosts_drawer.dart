import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/pic_net_models.dart';

class HostsDrawer extends StatelessWidget {
  const HostsDrawer({
    super.key,
    required this.hosts,
    this.selectedHost,
    this.onHostTap,
  });

  final List<PicHost> hosts;
  final PicHost? selectedHost;
  final void Function(PicHost host)? onHostTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final visibleHosts = hosts
        .where((h) => h.prepared == true)
        .toList(growable: false);

    if (visibleHosts.isEmpty) {
      return const Center(child: Text('暂无站点'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: const Text(
            '服务列表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: visibleHosts.length,
            itemBuilder: (context, index) {
              final host = visibleHosts[index];
              final url = host.hostUrl ?? '';
              final mark = host.mark ?? '';
              final tips = host.tips ?? '';
              final isSelected =
                  selectedHost != null &&
                  selectedHost!.mark != null &&
                  selectedHost!.mark == host.mark;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  elevation: isSelected ? 4 : 2,
                  // 不使用特殊背景色，只保留边框和文字高亮
                  color: null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isSelected
                        ? BorderSide(color: scheme.primary, width: 1.4)
                        : BorderSide.none,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      // 已选中的服务再次点击时不处理
                      if (isSelected) return;
                      onHostTap?.call(host);
                      _showCenterHud(context, '切换成功');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 20,
                            color: isSelected
                                ? scheme.primary
                                : theme.iconTheme.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  host.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? scheme.primary
                                        : theme.textTheme.bodyMedium?.color,
                                  ).merge(const TextStyle()),
                                  // 支持多行展示标题
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  url,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? scheme.primary.withValues(alpha: 0.8)
                                        : Colors.grey.shade600,
                                  ),
                                  // 支持多行展示 URL
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (mark.isNotEmpty || tips.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      mark,
                                      tips,
                                    ].where((e) => e.isNotEmpty).join(' · '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '复制地址',
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: url));
                              _showCenterHud(context, '复制成功');
                              // TODO: 复制按钮后续逻辑
                              // ignore: avoid_print
                              print('Copy clicked for host: ${host.title}');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCenterHud(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 1), () {
      entry.remove();
    });
  }
}
