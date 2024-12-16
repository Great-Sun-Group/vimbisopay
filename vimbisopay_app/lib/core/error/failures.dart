// Core failure types that can be extended by specific layers
abstract class Failure {
  final String? message;
  const Failure([this.message]);
}

// Domain-specific failures
class DomainFailure extends Failure {
  const DomainFailure([super.message]);
}

// Infrastructure failures
class InfrastructureFailure extends Failure {
  const InfrastructureFailure([super.message]);
}

// Server failures
class ServerFailure extends InfrastructureFailure {
  const ServerFailure([super.message]);
}

// Application failures
class ApplicationFailure extends Failure {
  const ApplicationFailure([super.message]);
}
