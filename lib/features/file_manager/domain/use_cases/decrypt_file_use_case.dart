import 'dart:io';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:cryptashell/core/error/failures.dart';
import 'package:cryptashell/features/file_manager/domain/repositories/file_repository.dart';

class DecryptFileUseCase {
  final FileRepository repository;
  DecryptFileUseCase(this.repository);

  Future<Either<Failure, List<File>>> call(DecryptFileParams params) async {
    if (params.passwordBytes.isEmpty) {
      return Left(
          ValidationFailure('The decryption password cannot be empty.'));
    }
    if (!params.archiveFile.existsSync()) {
      return Left(FileSystemFailure('The file does not exist.'));
    }
    return await repository.decryptArchive(
      archiveFile: params.archiveFile,
      passwordBytes: params.passwordBytes,
      outputDir: params.outputDir,
    );
  }
}

class DecryptFileParams {
  final File archiveFile;
  final Uint8List passwordBytes;
  final String outputDir;

  DecryptFileParams({
    required this.archiveFile,
    required this.passwordBytes,
    required this.outputDir,
  });
}
