import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:pic_data/persistence/pic_database.dart';
import 'package:pic_data/services/pic_download_module.dart';
import 'package:pic_data/services/pic_set_download_record_store.dart';

import 'pages/main_tab/main_tab_page.dart';
import 'services/download_concurrency_settings_service.dart';
import 'services/download_file_service.dart';
import 'services/net_client.dart';
import 'services/pic_net_service.dart';
import 'services/proxy_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ProxySettingsService.instance.load();
    await DownloadConcurrencySettingsService.instance.load();
    NetClient.attachProxySettingsListener();
    await PicNetService.instance.load();
    await DownloadFileService.instance.init();
    await PicDatabase.instance.init();
    await PicSetDownloadRecordStore.instance.loadFromDatabaseOnStartup();
    PicDownloadModule.instance.resumePersistedQueuedTasksIfAny();
    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'PicData',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const MainTabPage(),
          // const DevDebugOverlay(),
        ],
      ),
    );
  }
}
