import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/account.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

/// Use case for retrieving an account by its handle
class GetAccountByHandle {
  final AccountRepository repository;

  GetAccountByHandle(this.repository);

  /// Execute the use case
  /// Returns Either a Failure or the Account
  Future<Either<Failure, Account>> execute(String handle) async {
    if (handle.isEmpty) {
      return Left(DomainFailure('Account handle cannot be empty'));
    }
    
    // Handle validation could be moved to a value object
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(handle)) {
      return Left(DomainFailure('Invalid account handle format'));
    }

    return repository.getAccountByHandle(handle);
  }
}
