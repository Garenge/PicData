import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/pic_net_models.dart';

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
        _buildHeader(),
        const Divider(height: 1),
        Expanded(
          child: _buildHostList(
            context: context,
            visibleHosts: visibleHosts,
            theme: theme,
            scheme: scheme,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: const Text(
        '服务列表',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHostList({
    required BuildContext context,
    required List<PicHost> visibleHosts,
    required ThemeData theme,
    required ColorScheme scheme,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: visibleHosts.length,
      itemBuilder: (context, index) {
        final host = visibleHosts[index];
        final isSelected =
            selectedHost != null &&
            selectedHost!.mark != null &&
            selectedHost!.mark == host.mark;
        return _buildHostItem(
          context: context,
          host: host,
          isSelected: isSelected,
          theme: theme,
          scheme: scheme,
        );
      },
    );
  }

  Widget _buildHostItem({
    required BuildContext context,
    required PicHost host,
    required bool isSelected,
    required ThemeData theme,
    required ColorScheme scheme,
  }) {
    final url = host.hostUrl ?? '';
    final mark = host.mark ?? '';
    final tips = host.tips ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isSelected ? 4 : 2,
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
                _buildLeadingIcon(theme: theme, scheme: scheme, isSelected: isSelected),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildHostTexts(
                    theme: theme,
                    scheme: scheme,
                    host: host,
                    url: url,
                    mark: mark,
                    tips: tips,
                    isSelected: isSelected,
                  ),
                ),
                _buildCopyButton(context: context, host: host, url: url),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon({
    required ThemeData theme,
    required ColorScheme scheme,
    required bool isSelected,
  }) {
    return Icon(
      Icons.link,
      size: 20,
      color: isSelected ? scheme.primary : theme.iconTheme.color,
    );
  }

  Widget _buildHostTexts({
    required ThemeData theme,
    required ColorScheme scheme,
    required PicHost host,
    required String url,
    required String mark,
    required String tips,
    required bool isSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          host.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color:
                isSelected ? scheme.primary : theme.textTheme.bodyMedium?.color,
          ).merge(const TextStyle()),
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (mark.isNotEmpty || tips.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            [mark, tips].where((e) => e.isNotEmpty).join(' · '),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildCopyButton({
    required BuildContext context,
    required PicHost host,
    required String url,
  }) {
    return IconButton(
      tooltip: '复制地址',
      icon: const Icon(Icons.copy_outlined, size: 18),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: url));
        _showCenterHud(context, '复制成功');
        // TODO: 复制按钮后续逻辑
        // ignore: avoid_print
        print('Copy clicked for host: ${host.title}');
      },
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
