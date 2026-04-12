import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 队列 B（单图下载）最大并发数：持久化 + 内存权威，供 [PicDownloadModule] 与设置页使用。
class DownloadConcurrencySettingsService {
  DownloadConcurrencySettingsService._internal();

  static final DownloadConcurrencySettingsService instance =
      DownloadConcurrencySettingsService._internal();

  static const String _prefsKey = 'pic_max_concurrent_image_downloads';

  /// 与产品约定一致：下限 3，上限 20，默认 3。
  static const int kMinConcurrentImageDownloads = 3;
  static const int kMaxConcurrentImageDownloads = 20;
  static const int kDefaultConcurrentImageDownloads = kMinConcurrentImageDownloads;

  final ValueNotifier<int> maxConcurrentNotifier =
      ValueNotifier<int>(kDefaultConcurrentImageDownloads);

  int get maxConcurrentImageDownloads => maxConcurrentNotifier.value;

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? stored = prefs.getInt(_prefsKey);
    final int clamped = clampConcurrent(stored ?? kDefaultConcurrentImageDownloads);
    maxConcurrentNotifier.value = clamped;
    if (stored != null && stored != clamped) {
      await prefs.setInt(_prefsKey, clamped);
    }
  }

  static int clampConcurrent(int value) {
    return value.clamp(kMinConcurrentImageDownloads, kMaxConcurrentImageDownloads);
  }

  /// 写入本地并更新 [maxConcurrentNotifier]；调用方应在适当时机触发 [PicDownloadModule] 的队列调度刷新。
  Future<void> setMaxConcurrentImageDownloads(int value) async {
    final int v = clampConcurrent(value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, v);
    maxConcurrentNotifier.value = v;
  }
}
