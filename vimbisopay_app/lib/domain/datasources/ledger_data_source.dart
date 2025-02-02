import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';

/// Abstract class defining the contract for ledger data sources.
/// This can be implemented by both API and cache data sources.
abstract class LedgerDataSource {
  /// Retrieves ledger entries for a specific account.
  /// 
  /// [accountId] The ID of the account to fetch entries for
  /// [afterTimestamp] Optional. If provided, only returns entries after this timestamp
  /// [limit] Optional. Limits the number of entries returned
  Future<List<LedgerEntry>> getLedgerEntries({
    required String accountId,
    DateTime? afterTimestamp,
    int? limit,
  });

  /// Saves a list of ledger entries to the data source.
  /// 
  /// [entries] The list of ledger entries to save
  Future<void> saveLedgerEntries(List<LedgerEntry> entries);
}
