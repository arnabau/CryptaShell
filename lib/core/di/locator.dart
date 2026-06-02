/*
The Injection Container (Locator)
This file is the CryptaShell connection map. We will teach the app how to build each piece in the correct order (from bottom to top)
*/

import 'package:get_it/get_it.dart';
import 'package:cryptashell/features/file_manager/presentation/bloc/file_manager_bloc.dart';
import 'package:cryptashell/core/services/encryption_service.dart';
import 'package:cryptashell/features/file_manager/data/data_sources/file_data_source.dart';
import 'package:cryptashell/features/file_manager/data/repositories/file_repository_impl.dart';
import 'package:cryptashell/features/file_manager/domain/repositories/file_repository.dart';
import 'package:cryptashell/features/file_manager/domain/use_cases/encrypt_file_use_case.dart';
import 'package:cryptashell/features/file_manager/domain/use_cases/decrypt_file_use_case.dart';

// Global instance of GetIt (Convention: usually called 'sl' for Service Locator)
final sl = GetIt.instance;

Future<void> initLocator() async {
  // ---------------------------------------------------------------------------
  // 1. CORE & EXTERNAL SERVICES (The deepest foundation)
  // LazySingleton: It is only created in RAM the first time it is used
  // ---------------------------------------------------------------------------
  sl.registerLazySingleton<CryptoService>(() => CryptoService());

  // ---------------------------------------------------------------------------
  // 2. DATA SOURCES (disk access)
  // Record the abstraction linked to its implementation.
  // ---------------------------------------------------------------------------
  sl.registerLazySingleton<FileDataSource>(() => FileDataSourceImpl());

  // ---------------------------------------------------------------------------
  // 3. REPOSITORIES (The bridge)
  // Automatically inject the dependencies that the constructor requests
  // ---------------------------------------------------------------------------
  sl.registerLazySingleton<FileRepository>(
    () => FileRepositoryImpl(
      dataSource: sl<FileDataSource>(),
      cryptoService: sl<CryptoService>(),
    ),
  );

  // ---------------------------------------------------------------------------
  // 4. USE CASES (business logic)
  // ---------------------------------------------------------------------------
  sl.registerLazySingleton(() => EncryptFileUseCase(sl<FileRepository>()));
  sl.registerLazySingleton(() => DecryptFileUseCase(sl<FileRepository>()));

  // ---------------------------------------------------------------------------
  // 5. PRESENTACIÓN (BLoCs)
  // Usamos Factory: Crea una instancia NUEVA cada vez que una pantalla lo pide.
  // Esto evita que estados "sucios" de vistas anteriores afecten nuevas vistas.
  // ---------------------------------------------------------------------------
  sl.registerFactory(
    () => FileManagerBloc(
      encryptUseCase:
          sl<EncryptFileUseCase>(), // <-- Nombre de parámetro corregido
      decryptUseCase: sl<DecryptFileUseCase>(), // <-- Agregado el inyector
    ),
  );
}
