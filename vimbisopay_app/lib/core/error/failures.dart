/// Core failure types that can be extended by specific layers
abstract class Failure {
  final String? message;
  const Failure([this.message]);
}

/// Domain-specific failures
class DomainFailure extends Failure {
  const DomainFailure([super.message]);
}

/// Infrastructure failures
class InfrastructureFailure extends Failure {
  const InfrastructureFailure([super.message]);
}

/// Server failures
class ServerFailure extends InfrastructureFailure {
  const ServerFailure([super.message]);
}

/// Not found failures
class NotFoundFailure extends InfrastructureFailure {
  const NotFoundFailure([super.message]);
}

/// Validation failures
class ValidationFailure extends InfrastructureFailure {
  const ValidationFailure([super.message]);
}

/// Application failures
class ApplicationFailure extends Failure {
  const ApplicationFailure([super.message]);
}

/// Authentication failures
class AuthFailure extends InfrastructureFailure {
  final String? code;
  
  const AuthFailure({
    String? message,
    this.code,
  }) : super(message);

  bool get isPasswordRequired => code == 'PASSWORD_REQUIRED';
}
