import 'package:flutter/material.dart';

import 'package:pic_data/pages/Home/home_page.dart';
import 'package:pic_data/pages/main_tab/tab_root_navigator.dart';

class NavigationPage extends StatelessWidget {
  const NavigationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return TabRootNavigator(
      homeBuilder: (_) => const HomePage(),
    );
  }
}
