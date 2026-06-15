import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pic_data/services/file_export_share_service.dart';

void main() {
  group('FileExportShareService', () {
    late Directory tempDir;
    late FileExportShareService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pic_data_share_test_');
      service = FileExportShareService(shareRootDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates a password-protected zip from a directory', () async {
      final Directory source = await _createTextFixture(tempDir);

      final File zipFile = await service.createZipFromDirectory(
        directoryPath: source.path,
        fileName: 'export',
        password: FileExportShareService.defaultPassword,
      );

      expect(zipFile.path, endsWith('export.zip'));
      expect(await zipFile.exists(), isTrue);
      final Archive unreadableArchive = ZipDecoder().decodeBytes(
        zipFile.readAsBytesSync(),
      );
      final ArchiveFile unreadableText = unreadableArchive.files.firstWhere(
        (ArchiveFile file) => file.name.endsWith('/hello.txt'),
      );
      expect(() => unreadableText.content, throwsA(isA<Object>()));

      final Archive archive = ZipDecoder().decodeBytes(
        zipFile.readAsBytesSync(),
        password: FileExportShareService.defaultPassword,
      );
      final ArchiveFile exportedText = archive.files.firstWhere(
        (ArchiveFile file) => file.name.endsWith('/hello.txt'),
      );
      expect(String.fromCharCodes(exportedText.content as List<int>), 'hello');
    });

    test('creates a pdf from images', () async {
      final File image = await _createPngFixture(tempDir);

      final File pdfFile = await service.createPdfFromImages(
        imagePaths: <String>[image.path],
        fileName: 'images',
      );

      expect(pdfFile.path, endsWith('images.pdf'));
      expect(await pdfFile.exists(), isTrue);
      final List<int> bytes = await pdfFile.readAsBytes();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(100));
    });
  });
}

Future<Directory> _createTextFixture(Directory tempDir) async {
  final Directory source = Directory('${tempDir.path}/source');
  await source.create();
  await File('${source.path}/hello.txt').writeAsString('hello', flush: true);
  return source;
}

Future<File> _createPngFixture(Directory tempDir) async {
  final img.Image source = img.Image(width: 2, height: 2);
  img.fill(source, color: img.ColorRgb8(255, 0, 0));
  final Uint8List raster = Uint8List.fromList(img.encodePng(source));
  final File image = File('${tempDir.path}/pixel.png');
  await image.writeAsBytes(raster, flush: true);
  return image;
}
