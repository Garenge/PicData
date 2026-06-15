import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 下载并发数：持久化 + 内存权威，供 [PicDownloadModule] 与设置页使用。
class DownloadConcurrencySettingsService {
  DownloadConcurrencySettingsService._internal();

  static final DownloadConcurrencySettingsService instance =
      DownloadConcurrencySettingsService._internal();

  static const String _imagePrefsKey = 'pic_max_concurrent_image_downloads';
  static const String _setPrefsKey = 'pic_max_concurrent_set_downloads';

  /// 与产品约定一致：下限 3，上限 20，默认 3。
  static const int kMinConcurrentImageDownloads = 3;
  static const int kMaxConcurrentImageDownloads = 20;
  static const int kDefaultConcurrentImageDownloads =
      kMinConcurrentImageDownloads;

  /// 队列 A（套图任务）最大并发数：默认串行，允许用户保守放大到 3 套。
  static const int kMinConcurrentSetDownloads = 1;
  static const int kMaxConcurrentSetDownloads = 3;
  static const int kDefaultConcurrentSetDownloads = kMinConcurrentSetDownloads;

  final ValueNotifier<int> maxConcurrentNotifier = ValueNotifier<int>(
    kDefaultConcurrentImageDownloads,
  );
  final ValueNotifier<int> maxConcurrentSetNotifier = ValueNotifier<int>(
    kDefaultConcurrentSetDownloads,
  );

  int get maxConcurrentImageDownloads => maxConcurrentNotifier.value;
  int get maxConcurrentSetDownloads => maxConcurrentSetNotifier.value;

  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _loadImageDownloads(prefs);
    await _loadSetDownloads(prefs);
  }

  Future<void> _loadImageDownloads(SharedPreferences prefs) async {
    final int? stored = prefs.getInt(_imagePrefsKey);
    final int clamped = clampImageConcurrent(
      stored ?? kDefaultConcurrentImageDownloads,
    );
    maxConcurrentNotifier.value = clamped;
    if (stored != null && stored != clamped) {
      await prefs.setInt(_imagePrefsKey, clamped);
    }
  }

  Future<void> _loadSetDownloads(SharedPreferences prefs) async {
    final int? stored = prefs.getInt(_setPrefsKey);
    final int clamped = clampSetConcurrent(
      stored ?? kDefaultConcurrentSetDownloads,
    );
    maxConcurrentSetNotifier.value = clamped;
    if (stored != null && stored != clamped) {
      await prefs.setInt(_setPrefsKey, clamped);
    }
  }

  static int clampImageConcurrent(int value) {
    return value.clamp(
      kMinConcurrentImageDownloads,
      kMaxConcurrentImageDownloads,
    );
  }

  static int clampSetConcurrent(int value) {
    return value.clamp(kMinConcurrentSetDownloads, kMaxConcurrentSetDownloads);
  }

  /// 写入本地并更新 [maxConcurrentNotifier]；调用方应在适当时机触发 [PicDownloadModule] 的队列调度刷新。
  Future<void> setMaxConcurrentImageDownloads(int value) async {
    final int v = clampImageConcurrent(value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_imagePrefsKey, v);
    maxConcurrentNotifier.value = v;
  }

  /// 写入本地并更新 [maxConcurrentSetNotifier]；调用方应在适当时机触发队列 A 调度刷新。
  Future<void> setMaxConcurrentSetDownloads(int value) async {
    final int v = clampSetConcurrent(value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_setPrefsKey, v);
    maxConcurrentSetNotifier.value = v;
  }
}
