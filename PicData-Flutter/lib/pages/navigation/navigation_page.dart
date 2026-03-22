import 'package:flutter/material.dart';

import '../Home/home_page.dart';
import '../main_tab/tab_root_navigator.dart';

class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TabRootNavigator(
      homeBuilder: (_) => const HomePage(),
    );
  }
}
