import 'dart:convert';

import 'package:pic_data/models/pic_set_download_record.dart';
import 'package:sqflite/sqflite.dart';

const String _logCtx =
    'PicData-Flutter/lib/persistence/pic_set_download_record_dao.dart';

/// 套图下载记录表：与 [PicSetDownloadRecord] 字段对齐，供冷启动恢复与进度落盘。
class PicSetDownloadRecordDao {
  PicSetDownloadRecordDao(this._db);

  final Database _db;

  static const String tableName = 'pic_set_download_record';

  static Future<void> createTableV1(Database db) async {
    await db.execute('''
CREATE TABLE $tableName (
  id TEXT PRIMARY KEY NOT NULL,
  content_href TEXT NOT NULL,
  title TEXT NOT NULL,
  thumbnail_url TEXT NOT NULL,
  entry_detail_href TEXT NOT NULL,
  host_json TEXT NOT NULL,
  thumbnail_headers_json TEXT NOT NULL,
  status INTEGER NOT NULL,
  parse_pages_loaded INTEGER NOT NULL,
  parse_unique_images_so_far INTEGER NOT NULL,
  parse_finished INTEGER NOT NULL,
  planned_image_total INTEGER,
  image_jobs_succeeded INTEGER NOT NULL,
  image_jobs_failed INTEGER NOT NULL,
  parse_stopped_by_cycle INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  parse_started_at_ms INTEGER,
  parse_finished_at_ms INTEGER,
  completed_at_ms INTEGER,
  last_error_message TEXT,
  local_dir_relative TEXT NOT NULL
)
''');
  }

  Future<List<PicSetDownloadRecord>> queryAllOrderByCreatedDesc() async {
    final List<Map<String, Object?>> rows = await _db.query(
      tableName,
      orderBy: 'created_at_ms DESC',
    );
    final List<PicSetDownloadRecord> out = <PicSetDownloadRecord>[];
    for (final Map<String, Object?> row in rows) {
      try {
        out.add(_rowToRecord(row));
      } catch (e, st) {
        // ignore: avoid_print
        print('$_logCtx#queryAllOrderByCreatedDesc: skip bad row error=$e');
        // ignore: avoid_print
        print('  stack=$st');
      }
    }
    return out;
  }

  Future<void> upsert(PicSetDownloadRecord r) async {
    await _db.insert(
      tableName,
      _recordToRow(r),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteById(String id) async {
    await _db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  Map<String, Object?> _recordToRow(PicSetDownloadRecord r) {
    final PicSetDownloadProgress p = r.progress;
    return <String, Object?>{
      'id': r.id,
      'content_href': r.contentHref,
      'title': r.title,
      'thumbnail_url': r.thumbnailUrl,
      'entry_detail_href': r.entryDetailHref,
      'host_json': jsonEncode(r.host.toJson()),
      'thumbnail_headers_json': jsonEncode(r.thumbnailHttpHeaders),
      'status': _statusToInt(r.status),
      'parse_pages_loaded': p.parsePagesLoaded,
      'parse_unique_images_so_far': p.parseUniqueImagesSoFar,
      'parse_finished': p.parseFinished ? 1 : 0,
      'planned_image_total': p.plannedImageTotal,
      'image_jobs_succeeded': p.imageJobsSucceeded,
      'image_jobs_failed': p.imageJobsFailed,
      'parse_stopped_by_cycle': p.parseStoppedByCycle ? 1 : 0,
      'created_at_ms': r.createdAt.millisecondsSinceEpoch,
      'parse_started_at_ms': r.parseStartedAt?.millisecondsSinceEpoch,
      'parse_finished_at_ms': r.parseFinishedAt?.millisecondsSinceEpoch,
      'completed_at_ms': r.completedAt?.millisecondsSinceEpoch,
      'last_error_message': r.lastErrorMessage,
      'local_dir_relative': r.localDirRelativeToApplicationDocuments,
    };
  }

  PicSetDownloadRecord _rowToRecord(Map<String, Object?> row) {
    final Map<String, dynamic> hostMap =
        jsonDecode(row['host_json']! as String) as Map<String, dynamic>;
    final Map<String, dynamic> headersMap =
        jsonDecode(row['thumbnail_headers_json']! as String)
            as Map<String, dynamic>;
    final Map<String, String> headers = headersMap.map(
      (String k, dynamic v) => MapEntry(k, v.toString()),
    );

    return PicSetDownloadRecord(
      id: row['id']! as String,
      contentHref: row['content_href']! as String,
      title: row['title']! as String,
      thumbnailUrl: row['thumbnail_url']! as String,
      entryDetailHref: row['entry_detail_href']! as String,
      host: PicHostSnapshot.fromJson(hostMap),
      status: _statusFromInt((row['status'] as num).toInt()),
      thumbnailHttpHeaders: Map<String, String>.unmodifiable(headers),
      progress: PicSetDownloadProgress(
        parsePagesLoaded: (row['parse_pages_loaded'] as num).toInt(),
        parseUniqueImagesSoFar:
            (row['parse_unique_images_so_far'] as num).toInt(),
        parseFinished: (row['parse_finished'] as num).toInt() != 0,
        plannedImageTotal: row['planned_image_total'] == null
            ? null
            : (row['planned_image_total'] as num).toInt(),
        imageJobsSucceeded: (row['image_jobs_succeeded'] as num).toInt(),
        imageJobsFailed: (row['image_jobs_failed'] as num).toInt(),
        parseStoppedByCycle:
            (row['parse_stopped_by_cycle'] as num).toInt() != 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at_ms'] as num).toInt(),
      ),
      parseStartedAt: row['parse_started_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (row['parse_started_at_ms'] as num).toInt(),
            ),
      parseFinishedAt: row['parse_finished_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (row['parse_finished_at_ms'] as num).toInt(),
            ),
      completedAt: row['completed_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (row['completed_at_ms'] as num).toInt(),
            ),
      lastErrorMessage: row['last_error_message'] as String?,
      localDirRelativeToApplicationDocuments: row['local_dir_relative']! as String,
    );
  }

  static int _statusToInt(PicSetDownloadTaskStatus s) {
    switch (s) {
      case PicSetDownloadTaskStatus.queued:
        return 0;
      case PicSetDownloadTaskStatus.inProgress:
        return 1;
      case PicSetDownloadTaskStatus.completed:
        return 2;
      case PicSetDownloadTaskStatus.failed:
        return 3;
    }
  }

  static PicSetDownloadTaskStatus _statusFromInt(int v) {
    switch (v) {
      case 0:
        return PicSetDownloadTaskStatus.queued;
      case 1:
        return PicSetDownloadTaskStatus.inProgress;
      case 2:
        return PicSetDownloadTaskStatus.completed;
      case 3:
        return PicSetDownloadTaskStatus.failed;
      default:
        return PicSetDownloadTaskStatus.queued;
    }
  }
}
