import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';

/// Parameters for getting ledger entries
class GetLedgerParams {
  final String accountId;
  final DateTime? afterTimestamp;
  final int? limit;

  GetLedgerParams({
    required this.accountId,
    this.afterTimestamp,
    this.limit,
  });
}

/// Use case for retrieving account ledger/transaction history
class GetLedger {
  final AccountRepository repository;

  GetLedger(this.repository);

  /// Execute the use case
  /// Returns Either a Failure or List of LedgerEntry
  Future<Either<Failure, List<LedgerEntry>>> execute([GetLedgerParams? params]) {
    if (params == null) {
      throw ArgumentError('GetLedgerParams is required');
    }
    return repository.getLedger(
      accountId: params.accountId,
      afterTimestamp: params.afterTimestamp,
      limit: params.limit,
    );
  }
}
