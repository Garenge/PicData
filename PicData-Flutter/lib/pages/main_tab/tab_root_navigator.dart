import 'package:flutter/material.dart';

/// 底部 tab 内的嵌套路由栈：子页面 `push` 只叠在本 tab 上，
/// 不会盖住外层 [MainTabPage] 的 [BottomNavigationBar]。
class TabRootNavigator extends StatelessWidget {
  const TabRootNavigator({super.key, required this.homeBuilder});

  final WidgetBuilder homeBuilder;

  @override
  Widget build(BuildContext context) {
    return Navigator(
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
