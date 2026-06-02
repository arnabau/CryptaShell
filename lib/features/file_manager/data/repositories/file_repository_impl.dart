/*
The Data Bridge (Repository Implementation)
This component implements the domain layer contract (FileRepository).

It coordinates the FileDataSource and the CryptoService, catches any exceptions
and transforms them into a safe Either<Failure, File> flow.

Everything is handled at the Uint8List level (Dart byte arrays),
ensuring absolute compatibility in Apple (APFS) and Linux (ext4) file systems.
*/

import 'dart:io';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:cryptashell/core/error/failures.dart';
import 'package:cryptashell/core/services/encryption_service.dart';
import 'package:cryptashell/features/file_manager/domain/repositories/file_repository.dart';
import 'package:cryptashell/features/file_manager/data/data_sources/file_data_source.dart';
//import 'package:cryptashell/core/utils/encryption_utils.dart';
import 'package:cryptashell/core/utils/archive_service.dart';

class FileRepositoryImpl implements FileRepository {
  final FileDataSource dataSource;
  final CryptoService cryptoService;

  // Injection builder
  FileRepositoryImpl({
    required this.dataSource,
    required this.cryptoService,
  });

  @override
  Future<Either<Failure, File>> encryptElements({
    required List<FileSystemEntity> elements,
    required Uint8List passwordBytes,
    required bool removeMetadata,
    required String outputPath,
  }) async {
    try {
      // 1. Consolidate the batch of files into a single byte sequence
      //Uint8List packedBytes = await CryptaArchivePacker.pack(elements);
      Uint8List packedBytes = await CryptaArchiveService.packElements(elements);

      // 2. Run cipher AES-256-GCM
      final encryptedBytes =
          await cryptoService.encryptBytes(packedBytes, passwordBytes);

      // 3. Physically writing to disk by forcing the emptying of hardware buffers (flushing)
      final encryptedFile =
          await dataSource.writeFileBytes(outputPath, encryptedBytes);

      // memory clean
      packedBytes.fillRange(0, packedBytes.length, 0);

      return Right(encryptedFile);
    } catch (e) {
      return Left(EncryptionFailure(
          'Packaging and encryption failure: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<File>>> decryptArchive({
    required File archiveFile,
    required Uint8List passwordBytes,
    required String outputDir,
  }) async {
    try {
      // 1. Read bytes from the single container
      final encryptedBytes = await dataSource.readFileBytes(archiveFile);

      // 2. Decrypt and validate cryptographic authenticity signature
      final decryptedBytes =
          await cryptoService.decryptBytes(encryptedBytes, passwordBytes);

      // 3. Unpack and restore the structure to the original directory
      //final extractedFiles = await CryptaArchivePacker.unpack(decryptedBytes, outputDir);
      final extractedFiles =
          await CryptaArchiveService.unpackElements(decryptedBytes, outputDir);

      decryptedBytes.fillRange(0, decryptedBytes.length, 0);

      return Right(extractedFiles);
    } catch (e) {
      return Left(EncryptionFailure(
          'Integrity failure: Incorrect key or altered bunker.'));
    }
  }
}
