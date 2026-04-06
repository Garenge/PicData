import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pic_data/persistence/pic_set_download_record_dao.dart';
import 'package:sqflite/sqflite.dart';

const String _logCtx = 'PicData-Flutter/lib/persistence/pic_database.dart';

/// 本地持久化入口：打开 SQLite、版本与 [PicSetDownloadRecordDao]。
class PicDatabase {
  PicDatabase._();

  static final PicDatabase instance = PicDatabase._();

  /// 与 OC 版及未来 migration 对齐时使用。
  static const String fileName = 'pic_data.sqlite';

  /// 逻辑库版本；表结构变更时递增并在 [openDatabase] 中 migration。
  static const int schemaVersion = 2;

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Database? _db;
  PicSetDownloadRecordDao? _downloadRecordsDao;

  /// 套图下载记录 DAO；须先 [init]。
  PicSetDownloadRecordDao get downloadRecords {
    final Database? d = _db;
    if (d == null) {
      throw StateError('PicDatabase not initialized; call init() first');
    }
    return _downloadRecordsDao ??= PicSetDownloadRecordDao(d);
  }

  /// 打开连接、建表。
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final String path = p.join(dir.path, fileName);
    _db = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (Database db, int version) async {
        await PicSetDownloadRecordDao.createTableV1(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          await PicSetDownloadRecordDao.migrateV1ToV2(db);
        }
      },
    );
    _initialized = true;
  }

  /// 释放连接；应用退出时可调用。
  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }
    _downloadRecordsDao = null;
    final Database? d = _db;
    _db = null;
    _initialized = false;
    if (d != null) {
      try {
        await d.close();
      } catch (e, st) {
        // ignore: avoid_print
        print('$_logCtx#dispose: close failed: $e');
        // ignore: avoid_print
        print('  stack=$st');
      }
    }
  }
}
