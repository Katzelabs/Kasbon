import 'package:equatable/equatable.dart';

/// Base class for all failures in the application
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  List<Object?> get props => [message, code];
}

/// Failure for database operations
class DatabaseFailure extends Failure {
  const DatabaseFailure({
    required super.message,
    super.code,
  });
}

/// Failure for cache operations
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.code,
  });
}

/// Failure for validation errors
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code,
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

/// Failure for unexpected errors
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'Terjadi kesalahan yang tidak terduga',
    super.code,
  });
}

/// Failure for not found errors
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    required super.message,
    super.code,
  });
}

/// Failure for backup/restore operations
class BackupFailure extends Failure {
  const BackupFailure({
    required super.message,
    super.code,
  });
}

/// Failure for file system operations
class FileFailure extends Failure {
  const FileFailure({
    required super.message,
    super.code,
  });
}

/// Failure for authentication operations
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code,
  });
}

/// Failure for network operations
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
  });
}
