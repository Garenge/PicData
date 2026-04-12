import 'package:flutter/material.dart';

import 'package:pic_data/pages/Home/home_page.dart';
import 'package:pic_data/pages/main_tab/tab_root_navigator.dart';

class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return TabRootNavigator(
      navigatorKey: navigatorKey,
      homeBuilder: (_) => const HomePage(),
    );
  }
}
