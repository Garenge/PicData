import 'package:flutter/material.dart';

/// 仅包裹「文件」Tab 的 [Navigator]，用于在子路由栈中注册 [FileBrowserPage] 的刷新回调。
///
/// 点击底部「文件」Tab 时只刷新**当前可见目录**，不 pop 回根目录。
class FilesTabRefreshScope extends StatefulWidget {
  const FilesTabRefreshScope({super.key, required this.child});

  final Widget child;

  static FilesTabRefreshScopeState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<FilesTabRefreshScopeState>();
  }

  @override
  State<FilesTabRefreshScope> createState() => FilesTabRefreshScopeState();
}

class FilesTabRefreshScopeState extends State<FilesTabRefreshScope> {
  final List<Future<void> Function()> _refreshers = <Future<void> Function()>[];

  /// [FileBrowserPage] 在挂载时注册，dispose 时注销；顺序与导航栈一致（最后一项为栈顶页）。
  void registerRefresh(Future<void> Function() fn) {
    if (!_refreshers.contains(fn)) {
      _refreshers.add(fn);
    }
  }

  void unregisterRefresh(Future<void> Function() fn) {
    _refreshers.remove(fn);
  }

  Future<void> refreshTop() async {
    if (_refreshers.isEmpty) {
      return;
    }
    await _refreshers.last();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
