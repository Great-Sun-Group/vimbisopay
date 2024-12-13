import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/account.dart';

abstract class AccountRepository {
  /// Get current user's account details
  Future<Either<Failure, Account>> getCurrentAccount();
  
  /// Get current account balances
  Future<Either<Failure, Map<String, double>>> getBalances();
  
  /// Get current account ledger/transaction history
  Future<Either<Failure, List<dynamic>>> getLedger({int? startRow, int? numRows});

  /// Get account by handle (needed for creating transactions)
  Future<Either<Failure, Account>> getAccountByHandle(String handle);
}
