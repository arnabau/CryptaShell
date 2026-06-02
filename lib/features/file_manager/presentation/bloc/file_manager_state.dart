import 'dart:io';
import 'package:equatable/equatable.dart';

abstract class FileManagerState extends Equatable {
  const FileManagerState();
  @override
  List<Object?> get props => [];
}

class FileManagerInitial extends FileManagerState {}

class FileManagerLoading extends FileManagerState {}

class FileManagerSuccess extends FileManagerState {
  final List<File> files; // Soporta el conjunto de archivos operados con éxito
  final bool isEncrypted;

  const FileManagerSuccess({required this.files, required this.isEncrypted});

  @override
  List<Object?> get props => [files, isEncrypted];
}

class FileManagerError extends FileManagerState {
  final String message;
  const FileManagerError(this.message);
  @override
  List<Object?> get props => [message];
}
