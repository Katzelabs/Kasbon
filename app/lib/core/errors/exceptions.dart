/// Base class for all exceptions in the application
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Exception for database operations
class DatabaseException extends AppException {
  const DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exception for cache operations
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exception for validation errors
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code,
    this.fieldErrors,
  });
}

/// Exception for not found errors
class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.code,
  });
}

/// Exception for backup/restore operations
class BackupException extends AppException {
  const BackupException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exception for file system operations
class FileException extends AppException {
  const FileException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exception for image storage operations
class ImageStorageException extends AppException {
  const ImageStorageException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exception for authentication operations
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Exception for network operations
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.code,
    super.originalError,
  });
}
