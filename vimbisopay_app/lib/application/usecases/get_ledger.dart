import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';

/// Parameters for getting ledger entries
class GetLedgerParams {
  final String accountId;
  final int? startRow;
  final int? numRows;

  GetLedgerParams({
    required this.accountId,
    this.startRow,
    this.numRows,
  });
}

/// Use case for retrieving account ledger/transaction history
class GetLedger {
  final AccountRepository repository;

  GetLedger(this.repository);

  /// Execute the use case
  /// Returns Either a Failure or Map containing ledger data
  Future<Either<Failure, Map<String, dynamic>>> execute([GetLedgerParams? params]) {
    if (params == null) {
      throw ArgumentError('GetLedgerParams is required');
    }
    return repository.getLedger(
      accountId: params.accountId,
      startRow: params.startRow,
      numRows: params.numRows,
    );
  }
}
