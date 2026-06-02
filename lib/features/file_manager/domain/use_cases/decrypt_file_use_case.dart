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
      return Left(ValidationFailure(
          'La contraseña de descifrado no puede estar vacía.'));
    }
    if (!params.archiveFile.existsSync()) {
      return Left(
          FileSystemFailure('El búnker .crypta seleccionado no existe.'));
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
