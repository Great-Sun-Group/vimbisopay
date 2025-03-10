/// Base class for all exceptions in the application.
abstract class AppException implements Exception {
  final String message;
  const AppException([this.message = 'An unexpected error occurred']);
}

/// Exception thrown when a resource is not found.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Resource not found']);
}

/// Exception thrown when a server error occurs.
class ServerException extends AppException {
  const ServerException([super.message = 'Server error']);
}

/// Exception thrown when too many requests are made.
class RateLimitException extends AppException {
  const RateLimitException([super.message = 'Too many requests, please try again later']);
}

/// Exception thrown when a validation error occurs.
class ValidationException extends AppException {
  const ValidationException([super.message = 'Validation error']);
}

/// Exception thrown when an authentication error occurs.
class AuthException extends AppException {
  const AuthException([super.message = 'Authentication error']);
}
