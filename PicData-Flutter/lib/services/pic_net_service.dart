import 'package:flutter/services.dart' show rootBundle;
import 'package:lpinyin/lpinyin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pic_net_models.dart';

PicNetConfig? globalPicNetConfig;

class PicNetService {
  PicNetService._internal();

  static final PicNetService instance = PicNetService._internal();

  static const _selectedHostMarkKey = 'selected_host_mark';

  PicNetConfig? _config;
  PicHost? _selectedHost;

  PicNetConfig? get config => _config;

  List<PicHost> get hosts => _config?.hosts ?? <PicHost>[];

  List<String> get globalSearchKeys => _config?.globalSearchKeys ?? <String>[];

  PicHost? get selectedHost => _selectedHost;

  Future<void> load() async {
    final jsonStr = await rootBundle.loadString('assets/config/PicNet.json');
    _config = parsePicNetConfig(jsonStr);

    // 按拼音对全局搜索关键词排序，便于后续展示和索引
    final keys = _config?.globalSearchKeys;
    if (keys != null && keys.isNotEmpty) {
      keys.sort((a, b) {
        final pa = PinyinHelper.getPinyinE(a, separator: '', defPinyin: a);
        final pb = PinyinHelper.getPinyinE(b, separator: '', defPinyin: b);
        return pa.compareTo(pb);
      });
    }

    await _initSelectedHost();

    globalPicNetConfig = _config;
  }

  Future<void> _initSelectedHost() async {
    final visibleHosts =
        hosts.where((h) => h.prepared == true).toList(growable: false);
    if (visibleHosts.isEmpty) {
      _selectedHost = null;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedMark = prefs.getString(_selectedHostMarkKey);

    PicHost? matched;
    if (savedMark != null && savedMark.isNotEmpty) {
      matched = visibleHosts.firstWhere(
        (h) => h.mark == savedMark,
        orElse: () => visibleHosts.first,
      );
    } else {
      matched = visibleHosts.first;
    }

    _selectedHost = matched;
    await prefs.setString(_selectedHostMarkKey, matched.mark ?? '');
  }

  Future<void> setSelectedHost(PicHost host) async {
    _selectedHost = host;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedHostMarkKey, host.mark ?? '');
  }
}
