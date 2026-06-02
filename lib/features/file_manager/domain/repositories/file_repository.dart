import 'dart:io';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:cryptashell/core/error/failures.dart';

abstract class FileRepository {
  Future<Either<Failure, File>> encryptElements({
    required List<FileSystemEntity> elements,
    required Uint8List passwordBytes,
    required bool removeMetadata,
    required String outputPath,
  });

  Future<Either<Failure, List<File>>> decryptArchive({
    required File archiveFile,
    required Uint8List passwordBytes,
    required String outputDir,
  });
}
