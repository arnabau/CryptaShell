import 'dart:io';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:cryptashell/core/error/failures.dart';
import 'package:cryptashell/features/file_manager/domain/repositories/file_repository.dart';

class EncryptFileUseCase {
  final FileRepository repository;

  // Dependency injection: The UseCase does not create the repository, it receives it.
  EncryptFileUseCase(this.repository);

  // The 'call' method allows you to execute the class as if it were a function: useCase(params)
  Future<Either<Failure, File>> call(EncryptFileParams params) async {
    if (params.passwordBytes.length < 8) {
      return Left(ValidationFailure(
          'The password must be at least 8 characters long to be secure.'));
    }

    if (params.elements.isEmpty) {
      return Left(FileSystemFailure('No files selected'));
    }

    // If it passes the rules, we delegate the heavy lifting to the repository.
    return await repository.encryptElements(
      elements: params.elements,
      passwordBytes: params.passwordBytes,
      removeMetadata: params.removeMetadata,
      outputPath: params.outputPath,
    );
  }
}

// helper class for packaging parameters in a clean way
class EncryptFileParams {
  final List<FileSystemEntity> elements;
  final Uint8List passwordBytes;
  final bool removeMetadata;
  final String outputPath;

  EncryptFileParams({
    required this.elements,
    required this.passwordBytes,
    required this.outputPath,
    this.removeMetadata = false,
  });
}
