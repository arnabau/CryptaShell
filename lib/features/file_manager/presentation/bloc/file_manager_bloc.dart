import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cryptashell/features/file_manager/domain/use_cases/encrypt_file_use_case.dart';
import 'package:cryptashell/features/file_manager/domain/use_cases/decrypt_file_use_case.dart';
import 'package:cryptashell/features/file_manager/presentation/bloc/file_manager_state.dart';

// --- EVENTOS REFACTORIZADOS ---
abstract class FileManagerEvent {}

class EncryptRequested extends FileManagerEvent {
  final List<FileSystemEntity> elements;
  final Uint8List passwordBytes;
  final bool removeMetadata;
  final String outputPath;

  EncryptRequested({
    required this.elements,
    required this.passwordBytes,
    required this.outputPath,
    required this.removeMetadata,
  });
}

class DecryptRequested extends FileManagerEvent {
  final File archiveFile;
  final Uint8List passwordBytes;
  final String outputDir;

  DecryptRequested({
    required this.archiveFile,
    required this.passwordBytes,
    required this.outputDir,
  });
}

// --- BLOC ---
class FileManagerBloc extends Bloc<FileManagerEvent, FileManagerState> {
  final EncryptFileUseCase encryptUseCase;
  final DecryptFileUseCase decryptUseCase;

  FileManagerBloc({
    required this.encryptUseCase,
    required this.decryptUseCase,
  }) : super(FileManagerInitial()) {
    on<EncryptRequested>((event, emit) async {
      emit(FileManagerLoading());

      final result = await encryptUseCase(
        EncryptFileParams(
          elements: event.elements,
          passwordBytes: event.passwordBytes,
          removeMetadata: event.removeMetadata,
          outputPath: event.outputPath,
        ),
      );

      result.fold(
        (failure) => emit(FileManagerError(failure.message)),
        (containerFile) =>
            emit(FileManagerSuccess(files: [containerFile], isEncrypted: true)),
      );
    });

    on<DecryptRequested>((event, emit) async {
      emit(FileManagerLoading());

      final result = await decryptUseCase(
        DecryptFileParams(
          archiveFile: event.archiveFile,
          passwordBytes: event.passwordBytes,
          outputDir: event.outputDir,
        ),
      );

      result.fold(
        (failure) => emit(FileManagerError(failure.message)),
        (extractedFiles) =>
            emit(FileManagerSuccess(files: extractedFiles, isEncrypted: false)),
      );
    });
  }
}
