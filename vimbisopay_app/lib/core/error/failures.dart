// Core failure types that can be extended by specific layers
abstract class Failure {
  final String message;
  const Failure(this.message);
}

// Domain-specific failures
class DomainFailure extends Failure {
  const DomainFailure(String message) : super(message);
}

// Infrastructure failures
class InfrastructureFailure extends Failure {
  const InfrastructureFailure(String message) : super(message);
}

// Application failures
class ApplicationFailure extends Failure {
  const ApplicationFailure(String message) : super(message);
}
