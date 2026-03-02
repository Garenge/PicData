import 'package:flutter/services.dart' show rootBundle;
import 'package:lpinyin/lpinyin.dart';

import '../models/pic_net_models.dart';

PicNetConfig? globalPicNetConfig;

class PicNetService {
  PicNetService._internal();

  static final PicNetService instance = PicNetService._internal();

  PicNetConfig? _config;

  PicNetConfig? get config => _config;

  List<PicHost> get hosts => _config?.hosts ?? <PicHost>[];

  List<String> get globalSearchKeys => _config?.globalSearchKeys ?? <String>[];

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

    globalPicNetConfig = _config;
  }
}
