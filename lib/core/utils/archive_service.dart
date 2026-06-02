/*
It takes any mix of files and folders, respects their internal paths,
and turns them into a single block of bytes in RAM, ready to be encrypted.
*/

import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';

class CryptaArchiveService {
  /// It iterates through lists of files/folders and generates a single ZIP buffer in memory
  static Future<Uint8List> packElements(List<FileSystemEntity> elements) async {
    final archive = Archive();

    for (final entity in elements) {
      if (entity is File) {
        final bytes = await entity.readAsBytes();
        // Save only the name of the file
        final name = entity.path.split(Platform.pathSeparator).last;
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      } else if (entity is Directory) {
        // Read the folder recursively
        final parentPathLength = entity.parent.path.length + 1;

        await for (final subEntity in entity.list(recursive: true)) {
          if (subEntity is File) {
            final bytes = await subEntity.readAsBytes();
            // Maintain the internal structure of the folder (in. "My Folder/photo.jpg")
            final relativePath = subEntity.path.substring(parentPathLength);
            archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
          }
        }
      }
    }

    // Compress without touching the hard drive
    final zipEncoder = ZipEncoder();
    final compressedBytes = zipEncoder.encode(archive);
    return Uint8List.fromList(compressedBytes);
  }

  /// Unpack a ZIP buffer and recreate the folder structure on the disk
  static Future<List<File>> unpackElements(
      Uint8List zipBytes, String outputDir) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final List<File> extractedFiles = [];

    for (final file in archive) {
      if (file.isFile) {
        final data = file.content as List<int>;
        final outputFile =
            File('$outputDir${Platform.pathSeparator}${file.name}');

        // Created subfolders if the file came inside one
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(data, flush: true);

        extractedFiles.add(outputFile);
      }
    }
    return extractedFiles;
  }
}
