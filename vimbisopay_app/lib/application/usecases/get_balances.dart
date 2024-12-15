import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

/// Use case for retrieving current account balances
class GetBalances {
  final AccountRepository repository;

  GetBalances(this.repository);

  /// Execute the use case
  /// Returns Either a Failure or Map of denomination to balance
  Future<Either<Failure, Map<String, double>>> execute() {
    return repository.getBalances();
  }
}
