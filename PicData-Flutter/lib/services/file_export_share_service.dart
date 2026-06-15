import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class FileExportShareService {
  const FileExportShareService({Directory? shareRootDirectory})
    : _shareRootDirectory = shareRootDirectory;

  static const String defaultPassword = '8888';
  static const String _shareFolderName = 'PicDataShare';
  final Directory? _shareRootDirectory;

  Future<File> createZipFromDirectory({
    required String directoryPath,
    required String fileName,
    String? password,
  }) async {
    final Directory sourceDir = Directory(directoryPath);
    if (!await sourceDir.exists()) {
      throw FileSystemException('待压缩文件夹不存在', directoryPath);
    }

    final File zipFile = await _newShareFile(_ensureExtension(fileName, 'zip'));
    final String? normalizedPassword = password?.trim();
    final encoder = ZipFileEncoder(
      password: normalizedPassword == null || normalizedPassword.isEmpty
          ? null
          : normalizedPassword,
    );
    var encoderOpened = false;
    try {
      encoder.create(zipFile.path, level: ZipFileEncoder.gzip);
      encoderOpened = true;
      await encoder.addDirectory(
        sourceDir,
        includeDirName: true,
        level: ZipFileEncoder.gzip,
      );
      await encoder.close();
      encoderOpened = false;
      return zipFile;
    } catch (_) {
      if (encoderOpened) {
        try {
          await encoder.close();
        } catch (_) {
          // Best effort cleanup before removing the incomplete temp zip.
        }
      }
      await _deleteIfExists(zipFile);
      rethrow;
    }
  }

  Future<File> createPdfFromImages({
    required List<String> imagePaths,
    required String fileName,
  }) async {
    if (imagePaths.isEmpty) {
      throw const FileExportShareException('当前目录没有可生成 PDF 的图片');
    }

    final File pdfFile = await _newShareFile(_ensureExtension(fileName, 'pdf'));
    final pdf = pw.Document(
      title: p.basenameWithoutExtension(pdfFile.path),
      creator: 'PicData',
    );

    try {
      for (final String imagePath in imagePaths) {
        final Uint8List bytes = await File(imagePath).readAsBytes();
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(0),
            build: (pw.Context context) =>
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }

      await pdfFile.writeAsBytes(
        await pdf.save(enableEventLoopBalancing: true),
        flush: true,
      );
      return pdfFile;
    } catch (_) {
      await _deleteIfExists(pdfFile);
      rethrow;
    }
  }

  Future<ShareResult> shareFile({
    required File file,
    required String title,
    Rect? sharePositionOrigin,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        title: title,
        files: <XFile>[XFile(file.path)],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<File> _newShareFile(String fileName) async {
    final Directory shareDir =
        _shareRootDirectory ??
        Directory(
          p.join((await getTemporaryDirectory()).path, _shareFolderName),
        );
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }
    return File(p.join(shareDir.path, fileName));
  }

  String _ensureExtension(String fileName, String extension) {
    final String trimmed = p.basename(fileName.trim());
    final String fallback = 'PicData.$extension';
    if (trimmed.isEmpty || p.basenameWithoutExtension(trimmed).isEmpty) {
      return fallback;
    }
    return p.extension(trimmed).toLowerCase() == '.$extension'
        ? trimmed
        : '$trimmed.$extension';
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class FileExportShareException implements Exception {
  const FileExportShareException(this.message);

  final String message;

  @override
  String toString() => message;
}
