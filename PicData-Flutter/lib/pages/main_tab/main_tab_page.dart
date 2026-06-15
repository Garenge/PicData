import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pic_data/debug/navigation_debug_logger.dart';
import 'package:pic_data/pages/Home/home_page.dart';
import 'package:pic_data/pages/downloads/downloads_page.dart';
import 'package:pic_data/pages/files/files_page.dart';
import 'package:pic_data/pages/files/files_tab_refresh_scope.dart';
import 'package:pic_data/pages/navigation/navigation_page.dart';
import 'package:pic_data/pages/settings/settings_page.dart';
import 'tab_root_navigator.dart';

class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _selectedIndex = 0;
  int _filesRefreshSignal = 0;
  int _downloadsRefreshSignal = 0;
  static final List<Type> _tabPageTypes = <Type>[
    HomePage,
    FilesPage,
    DownloadsPage,
    SettingsPage,
  ];

  /// 与 [IndexedStack] 中各 Tab 一一对应，用于系统返回 / 桌面 Backspace 只操作当前 Tab 的嵌套路由栈。
  late final List<GlobalKey<NavigatorState>> _tabNavigatorKeys =
      List<GlobalKey<NavigatorState>>.generate(
        4,
        (_) => GlobalKey<NavigatorState>(),
      );

  /// macOS / Windows / Linux / Web：键盘 Backspace 触发子栈 [Navigator.pop]（根页不退出应用）。
  bool get _keyboardBackspaceNavEnabled {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// 弹出当前 Tab 嵌套栈顶（若有）。返回是否执行了 pop。
  bool _tryPopCurrentTabNestedRoute() {
    final NavigatorState? nav = _tabNavigatorKeys[_selectedIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }
    return false;
  }

  void _onTap(int index) {
    logNavigationDebugPage(_tabPageTypes[index]);
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _filesRefreshSignal++;
      }
      if (index == 2) {
        _downloadsRefreshSignal++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget shell = PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (_tryPopCurrentTabNestedRoute()) {
          return;
        }
        if (defaultTargetPlatform == TargetPlatform.android) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: <Widget>[
            NavigationPage(navigatorKey: _tabNavigatorKeys[0]),
            FilesTabRefreshScope(
              child: TabRootNavigator(
                navigatorKey: _tabNavigatorKeys[1],
                homeBuilder: (_) =>
                    FilesPage(refreshSignal: _filesRefreshSignal),
              ),
            ),
            TabRootNavigator(
              navigatorKey: _tabNavigatorKeys[2],
              homeBuilder: (_) =>
                  DownloadsPage(refreshSignal: _downloadsRefreshSignal),
            ),
            TabRootNavigator(
              navigatorKey: _tabNavigatorKeys[3],
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
      ),
    );

    if (_keyboardBackspaceNavEnabled) {
      shell = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.backspace): () {
            _tryPopCurrentTabNestedRoute();
          },
        },
        child: shell,
      );
    }

    return shell;
  }
}
