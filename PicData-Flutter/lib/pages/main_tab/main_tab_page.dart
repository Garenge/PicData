import 'package:flutter/material.dart';

import '../downloads/downloads_page.dart';
import '../files/files_page.dart';
import '../navigation/navigation_page.dart';
import '../settings/settings_page.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const NavigationPage(),
    const FilesPage(),
    const DownloadsPage(),
    const SettingsPage(),
  ];

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
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
