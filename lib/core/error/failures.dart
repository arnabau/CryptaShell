abstract class Failure {
  final String message;
  Failure(this.message);
}

// Fallos específicos de nuestra app
class EncryptionFailure extends Failure {
  EncryptionFailure(super.message);
}

class FileSystemFailure extends Failure {
  FileSystemFailure(super.message);
}

class ValidationFailure extends Failure {
  ValidationFailure(super.message);
}
