/*
This utility will recursively read collections of files and folders, and consolidate them into a binary array
organized under the internal structure: [File Number] + [Name Length] + [UTF-8 Name] + [File Length] + [Actual Bytes]
*/

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

class CryptaArchivePacker {
  /// Packages a list of files and folders into a single flat binary stream
  static Future<Uint8List> pack(List<FileSystemEntity> entities) async {
    final builder = BytesBuilder();
    final List<File> allFiles = [];

    // Loop recursively to extract actual files from folders
    for (final entity in entities) {
      if (entity is File) {
        allFiles.add(entity);
      } else if (entity is Directory) {
        await for (final subEntity in entity.list(recursive: true)) {
          if (subEntity is File) {
            allFiles.add(subEntity);
          }
        }
      }
    }

    // 1. Write number of total files (4 bytes)
    final fileCountData = ByteData(4)..setUint32(0, allFiles.length);
    builder.add(fileCountData.buffer.asUint8List());

    for (final file in allFiles) {
      // Save relative path so as not to compromise the privacy of the host's absolute path
      final relativePath = file.path.split(Platform.pathSeparator).last;
      final nameBytes = utf8.encode(relativePath);
      final fileBytes = await file.readAsBytes();

      // 2. Name Length (4 bytes)
      final nameLenData = ByteData(4)..setUint32(0, nameBytes.length);
      builder.add(nameLenData.buffer.asUint8List());

      // 3. Name bytes
      builder.add(nameBytes);

      // 4. File data length (8 bytes to support files > 4GB)
      final fileLenData = ByteData(8)..setUint64(0, fileBytes.length);
      builder.add(fileLenData.buffer.asUint8List());

      // 5. File bytes
      builder.add(fileBytes);
    }

    return builder.toBytes();
  }

  /// Unpack binary array write the structure to the hard drive
  static Future<List<File>> unpack(
      Uint8List packedBytes, String targetDir) async {
    final List<File> unpackedFiles = [];
    final buffer = packedBytes.buffer.asByteData();
    int offset = 0;

    if (packedBytes.length < 4) return [];

    // 1. Read how many files
    final totalFiles = buffer.getUint32(offset);
    offset += 4;

    for (int i = 0; i < totalFiles; i++) {
      if (offset + 4 > packedBytes.length) break;

      // 2. Read name length
      final nameLen = buffer.getUint32(offset);
      offset += 4;

      // 3. Extract name
      final nameBytes = packedBytes.sublist(offset, offset + nameLen);
      offset += nameLen;
      final relativePath = utf8.decode(nameBytes);

      // 4. Read file's length
      final fileLen = buffer.getUint64(offset);
      offset += 8;

      // 5. Extract bytes from file
      final fileBytes = packedBytes.sublist(offset, offset + fileLen);
      offset += fileLen;

      // Rebuild atomically on target storage
      final outputFile =
          File('$targetDir${Platform.pathSeparator}$relativePath');
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(fileBytes, flush: true);
      unpackedFiles.add(outputFile);
    }

    return unpackedFiles;
  }
}
