// ignore_for_file: unused_local_variable

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Imported dependency injection
import 'package:cryptashell/core/di/locator.dart';

// Imported BLoC ans screen
import 'package:cryptashell/features/file_manager/presentation/bloc/file_manager_bloc.dart';
import 'package:cryptashell/features/file_manager/presentation/screens/file_manager_screen.dart';

void main(List<String> args) async {
  // Make sure native macOS channels are ready
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency bunker
  await initLocator();

  File? fileFromOS;
  bool startInDecryptMode = false;

  if (args.isNotEmpty) {
    final filePath = args.first;
    if (filePath.isNotEmpty) {
      fileFromOS = File(filePath);
      startInDecryptMode = filePath.endsWith('.crypta');
    }
  }

  runApp(CryptaShellApp(
      initialFile: fileFromOS, initialDecryptMode: startInDecryptMode));
}

class CryptaShellApp extends StatelessWidget {
  // 1. Declare immutable properties of the class
  final File? initialFile;
  final bool initialDecryptMode;

  // 2. map them directly in the constructor using 'this.'
  const CryptaShellApp({
    super.key,
    this.initialFile,
    required this.initialDecryptMode,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CryptaShell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.greenAccent,
        ),
      ),
      home: BlocProvider(
        create: (context) => sl<FileManagerBloc>(),
        child: FileManagerScreen(
          // 3. Display the variables on the screen
          initialFile: initialFile,
          initialDecryptMode: initialDecryptMode,
        ),
      ),
    );
  }
}
