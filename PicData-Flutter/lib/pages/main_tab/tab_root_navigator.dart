import 'package:flutter/material.dart';

import 'package:pic_data/debug/navigation_debug_logger.dart';

/// 底部 tab 内的嵌套路由栈：子页面 `push` 只叠在本 tab 上，
/// 不会盖住外层 [MainTabPage] 的 [BottomNavigationBar]。
class TabRootNavigator extends StatelessWidget {
  const TabRootNavigator({
    super.key,
    required this.homeBuilder,
    this.navigatorKey,
  });

  final WidgetBuilder homeBuilder;

  /// 供外层（如底部 Tab）在系统返回时只对当前 Tab 执行 [Navigator.pop]。
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      observers: <NavigatorObserver>[NavigationDebugObserver()],
      initialRoute: Navigator.defaultRouteName,
      onGenerateRoute: (RouteSettings settings) {
        if (settings.name == Navigator.defaultRouteName) {
          return MaterialPageRoute<void>(
            builder: homeBuilder,
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
