import 'dart:async';

/// 本地持久化入口。具体存储实现（sqflite / Drift 等）在后续迭代中接入。
///
/// 使用方式：在 [WidgetsFlutterBinding.ensureInitialized] 之后、首屏依赖数据之前调用 [init]。
class PicDatabase {
  PicDatabase._();

  static final PicDatabase instance = PicDatabase._();

  /// 与 OC 版及未来 migration 对齐时使用；仅作约定，尚未写入真实文件。
  static const String fileName = 'pic_data.sqlite';

  /// 逻辑库版本，供迁移脚本递增；实现层落地后与 user_version 对齐。
  static const int schemaVersion = 1;

  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// 打开连接、执行 migration、注册各 Repository 依赖。
  ///
  /// 当前为占位：仅占位初始化，避免业务层提前耦合具体 SDK。
  Future<void> init() async {
    if (_initialized) return;
    // TODO: path_provider 取应用目录，打开 SQLite，执行 CREATE / migration
    _initialized = true;
  }

  /// 释放连接与缓存；应用退出或热重启前可调用。
  Future<void> dispose() async {
    if (!_initialized) return;
    // TODO: close database / isolate pool
    _initialized = false;
  }
}
