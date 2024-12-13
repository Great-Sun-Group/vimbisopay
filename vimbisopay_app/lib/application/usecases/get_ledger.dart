import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/repositories/account_repository.dart';

/// Parameters for getting ledger entries
class GetLedgerParams {
  final int? startRow;
  final int? numRows;

  GetLedgerParams({this.startRow, this.numRows});
}

/// Use case for retrieving account ledger/transaction history
class GetLedger {
  final AccountRepository repository;

  GetLedger(this.repository);

  /// Execute the use case
  /// Returns Either a Failure or List of ledger entries
  Future<Either<Failure, List<dynamic>>> execute([GetLedgerParams? params]) {
    return repository.getLedger(
      startRow: params?.startRow,
      numRows: params?.numRows,
    );
  }
}
