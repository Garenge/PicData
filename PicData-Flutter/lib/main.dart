import 'package:flutter/material.dart';
import 'debug/dev_overlay.dart';

import 'pages/main_tab/main_tab_page.dart';
import 'services/download_file_service.dart';
import 'services/pic_net_service.dart';

void main() {
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
    await PicNetService.instance.load();
    await DownloadFileService.instance.init();
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
      ),
      home: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const MainTabPage(),
          const DevDebugOverlay(),
        ],
      ),
    );
  }
}
