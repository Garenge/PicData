import 'package:flutter/material.dart';

import '../downloads/downloads_page.dart';
import '../files/files_page.dart';
import '../navigation/navigation_page.dart';
import '../settings/settings_page.dart';
import 'tab_root_navigator.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _selectedIndex = 0;
  int _filesRefreshSignal = 0;

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _filesRefreshSignal++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          const NavigationPage(),
          TabRootNavigator(
            homeBuilder: (_) =>
                FilesPage(refreshSignal: _filesRefreshSignal),
          ),
          TabRootNavigator(
            homeBuilder: (_) => const DownloadsPage(),
          ),
          TabRootNavigator(
            homeBuilder: (_) => const SettingsPage(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '导航'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: '文件'),
          BottomNavigationBarItem(icon: Icon(Icons.download), label: '下载'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
