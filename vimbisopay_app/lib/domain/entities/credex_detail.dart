import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';

enum CredexStatus { pending, accepted, redeemed, cancelled, declined }

class ClearedTransaction {
  final String credexID;
  final String formattedClearedAmount;
  final String formattedInitialAmount;
  final String counterpartyAccountName;

  ClearedTransaction({
    required this.credexID,
    required this.formattedClearedAmount,
    required this.formattedInitialAmount,
    required this.counterpartyAccountName,
  });

  factory ClearedTransaction.fromJson(Map<String, dynamic> json) {
    return ClearedTransaction(
      credexID: json['credexID']?.toString() ?? '',
      formattedClearedAmount: json['amount']?.toString() ?? '',
      formattedInitialAmount: json['initialAmount']?.toString() ?? '',
      counterpartyAccountName: json['counterpartyName']?.toString() ?? '',
    );
  }
}

class CredexDetail {
  final String credexID;
  final String
      transactionType; // OWES, CLEARED, REQUESTS, OFFERS, DECLINED, CANCELLED
  final bool debit;
  final String counterpartyAccountName;
  final String? currentUserAccountName;
  final String? counterpartyAccountHandle;
  final String? currentUserAccountHandle;
  final String? issuerAccountHandle;
  final String? acceptorAccountHandle;
  final String? issuerAccountName;
  final String? acceptorAccountName;
  final String? securerName;
  final String denomination;
  final String? issuerAccountID;
  final String? acceptorAccountID;
  final double initialAmount;
  final double outstandingAmount;
  final double redeemedAmount;
  final double defaultedAmount;
  final double writtenOffAmount;
  final String formattedInitialAmount;
  final String formattedOutstandingAmount;
  final String formattedRedeemedAmount;
  final String formattedDefaultedAmount;
  final String formattedWrittenOffAmount;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? cancelledAt;
  final DateTime? dueDate;
  final bool securedCredex;
  final List<ClearedTransaction> clearedAgainst;

  // Member information for issuer
  final String? issuerMemberId;
  final String? issuerFirstName;
  final String? issuerLastName;
  final String? issuerHandle;
  final int? issuerTier;
  final String? issuerProfilePicture;
  final CreditRating? issuerCreditRating;

  // Member information for acceptor
  final String? acceptorMemberId;
  final String? acceptorFirstName;
  final String? acceptorLastName;
  final String? acceptorHandle;
  final int? acceptorTier;
  final String? acceptorProfilePicture;
  final CreditRating? acceptorCreditRating;

  CredexDetail({
    required this.credexID,
    required this.transactionType,
    required this.debit,
    required this.counterpartyAccountName,
    this.currentUserAccountName,
    this.counterpartyAccountHandle,
    this.currentUserAccountHandle,
    this.issuerAccountHandle,
    this.acceptorAccountHandle,
    this.issuerAccountName,
    this.acceptorAccountName,
    this.securerName,
    required this.denomination,
    this.issuerAccountID,
    this.acceptorAccountID,
    required this.initialAmount,
    required this.outstandingAmount,
    required this.redeemedAmount,
    required this.defaultedAmount,
    required this.writtenOffAmount,
    required this.formattedInitialAmount,
    required this.formattedOutstandingAmount,
    required this.formattedRedeemedAmount,
    required this.formattedDefaultedAmount,
    required this.formattedWrittenOffAmount,
    this.acceptedAt,
    this.declinedAt,
    this.cancelledAt,
    this.dueDate,
    required this.securedCredex,
    required this.clearedAgainst,
    this.issuerMemberId,
    this.issuerFirstName,
    this.issuerLastName,
    this.issuerHandle,
    this.issuerTier,
    this.issuerProfilePicture,
    this.issuerCreditRating,
    this.acceptorMemberId,
    this.acceptorFirstName,
    this.acceptorLastName,
    this.acceptorHandle,
    this.acceptorTier,
    this.acceptorProfilePicture,
    this.acceptorCreditRating,
  });

  // Computed properties
  CredexStatus get status {
    if (cancelledAt != null) return CredexStatus.cancelled;
    if (declinedAt != null) return CredexStatus.declined;
    if (transactionType == 'CLEARED') return CredexStatus.redeemed;
    if (acceptedAt != null) return CredexStatus.accepted;
    return CredexStatus.pending;
  }

  String get statusDisplayName {
    switch (status) {
      case CredexStatus.pending:
        return transactionType == 'OFFERS'
            ? 'Pending Acceptance'
            : 'Pending Response';
      case CredexStatus.accepted:
        return 'Accepted';
      case CredexStatus.redeemed:
        return 'Redeemed';
      case CredexStatus.cancelled:
        return 'Cancelled';
      case CredexStatus.declined:
        return 'Declined';
    }
  }

  bool get isPending => status == CredexStatus.pending;
  bool get isAccepted => status == CredexStatus.accepted;
  bool get isRedeemed => status == CredexStatus.redeemed;
  bool get isCancelled => status == CredexStatus.cancelled;
  bool get isDeclined => status == CredexStatus.declined;
  bool get isFinalized => isCancelled || isDeclined || isRedeemed;

  // Check if current user can perform actions
  // Note: These methods assume the UI will determine direction based on user context
  // For now, we use simplified logic that may need UI-level refinement
  bool get canAccept => isPending && transactionType == 'OFFERS';
  bool get canDecline => isPending && transactionType == 'OFFERS';
  bool get canCancel =>
      isPending &&
      (transactionType == 'OFFERS' || transactionType == 'REQUESTS');

  factory CredexDetail.fromApiResponse(Map<String, dynamic> apiData) {
    try {
      final action = apiData['action'] as Map<String, dynamic>? ?? {};
      final details = action['details'] as Map<String, dynamic>? ?? {};
      final status = details['status'] as Map<String, dynamic>? ?? {};
      final clearedAgainst = details['clearedAgainst'] as List<dynamic>? ?? [];

      // Parse dates
      DateTime? parseDate(String? dateStr) {
        if (dateStr == null || dateStr.isEmpty) return null;
        try {
          return DateTime.parse(dateStr);
        } catch (e) {
          Logger.error('Error parsing date: $dateStr', e);
          return null;
        }
      }

      // Parse amounts from formatted strings
      double parseAmount(String? formattedAmount) {
        if (formattedAmount == null || formattedAmount.isEmpty) return 0.0;
        try {
          // Extract numeric part from formatted string like "100.00 USD"
          final parts = formattedAmount.split(' ');
          if (parts.isNotEmpty) {
            return double.parse(parts[0]);
          }
          return 0.0;
        } catch (e) {
          Logger.error('Error parsing amount: $formattedAmount', e);
          return 0.0;
        }
      }

      // Note: Dashboard member data extraction removed - now using direct API fields from details

      // Store raw account names from API - UI will determine current user vs counterparty
      Logger.data(
          '[ACCOUNT_NAMES] Setting account names directly from API details');
      Logger.data('[ACCOUNT_NAMES] details keys: ${details.keys.toList()}');

      // Parse nested issuer/acceptor objects from new API structure
      final issuerData = details['issuer'] as Map<String, dynamic>?;
      final acceptorData = details['acceptor'] as Map<String, dynamic>?;

      // Extract account IDs from nested issuer/acceptor objects
      final issuerAccountID = issuerData?['accountID']?.toString();
      final acceptorAccountID = acceptorData?['accountID']?.toString();

      Logger.data('[ACCOUNT_IDS] issuerAccountID: $issuerAccountID');
      Logger.data('[ACCOUNT_IDS] acceptorAccountID: $acceptorAccountID');

      // Store issuer and acceptor account info - UI will resolve current user positioning
      final issuerAccountName = issuerData != null ? issuerData['accountName'] as String? : null;
      final acceptorAccountName = acceptorData != null ? acceptorData['accountName'] as String? : null;
      final issuerAccountHandleRaw = issuerData != null ? issuerData['accountHandle'] as String? : null;
      final acceptorAccountHandleRaw = acceptorData != null ? acceptorData['accountHandle'] as String? : null;

      // For backward compatibility, set defaults (will be overridden by UI logic)
      final currentUserAccountName = issuerAccountName; // Temporary default
      final counterpartyAccountName = acceptorAccountName; // Temporary default
      final currentUserAccountHandle =
          issuerAccountHandleRaw; // Temporary default
      final counterpartyAccountHandle =
          acceptorAccountHandleRaw; // Temporary default

      // Debit will be determined by UI based on user context
      final isDebit = false; // Temporary default - UI will set this properly

      Logger.data(
          '[ACCOUNT_NAMES] currentUserAccountName: $currentUserAccountName');
      Logger.data(
          '[ACCOUNT_NAMES] counterpartyAccountName: $counterpartyAccountName');
      Logger.data('Is Debit: $isDebit');
      Logger.data('Action details keys: ${details.keys.toList()}');

      Logger.data('[MEMBER_DATA] Direct parsing from action.details');

      // Extract issuer member data from nested issuer object
      final issuerMemberId = issuerData?['memberID']?.toString();
      final issuerFirstName = issuerData?['firstName']?.toString();
      final issuerLastName = issuerData?['lastName']?.toString();
      final issuerHandle = issuerData?['handle']?.toString();

      // Parse issuer tier (object with low/high or direct value)
      int? issuerTier;
      final issuerTierData = issuerData?['tier'];
      if (issuerTierData is Map<String, dynamic>) {
        issuerTier = issuerTierData['low'] as int?;
      } else {
        issuerTier = issuerTierData as int?;
      }

      final issuerProfilePicture = issuerData?['profilePicture']?.toString();

      // Parse issuer credit rating
      CreditRating? issuerCreditRating;
      final issuerCreditRatingData =
          issuerData?['creditRating'] as Map<String, dynamic>?;
      if (issuerCreditRatingData != null) {
        issuerCreditRating = CreditRating(
          redeemedTotalUSD:
              (issuerCreditRatingData['redeemedTotal'] as num?)?.toDouble() ??
                  0.0,
          outstandingTotalUSD:
              (issuerCreditRatingData['outstandingTotal'] as num?)
                      ?.toDouble() ??
                  0.0,
          defaultedTotalUSD:
              (issuerCreditRatingData['defaultedTotal'] as num?)?.toDouble() ??
                  0.0,
          writtenOffTotalUSD:
              (issuerCreditRatingData['writtenOffTotal'] as num?)?.toDouble() ??
                  0.0,
        );
      }

      // Extract acceptor member data from nested acceptor object
      final acceptorMemberId = acceptorData?['memberID']?.toString();
      final acceptorFirstName = acceptorData?['firstName']?.toString();
      final acceptorLastName = acceptorData?['lastName']?.toString();
      final acceptorHandle = acceptorData?['handle']?.toString();

      // Parse acceptor tier (object with low/high or direct value)
      int? acceptorTier;
      final acceptorTierData = acceptorData?['tier'];
      if (acceptorTierData is Map<String, dynamic>) {
        acceptorTier = acceptorTierData['low'] as int?;
      } else {
        acceptorTier = acceptorTierData as int?;
      }

      final acceptorProfilePicture = acceptorData?['profilePicture']?.toString();

      // Parse acceptor credit rating
      CreditRating? acceptorCreditRating;
      final acceptorCreditRatingData =
          acceptorData?['creditRating'] as Map<String, dynamic>?;
      if (acceptorCreditRatingData != null) {
        acceptorCreditRating = CreditRating(
          redeemedTotalUSD:
              (acceptorCreditRatingData['redeemedTotal'] as num?)?.toDouble() ??
                  0.0,
          outstandingTotalUSD:
              (acceptorCreditRatingData['outstandingTotal'] as num?)
                      ?.toDouble() ??
                  0.0,
          defaultedTotalUSD:
              (acceptorCreditRatingData['defaultedTotal'] as num?)
                      ?.toDouble() ??
                  0.0,
          writtenOffTotalUSD:
              (acceptorCreditRatingData['writtenOffTotal'] as num?)?.
                      toDouble() ??
                  0.0,
        );
      }

      Logger.data(
          '[MEMBER_DATA] Parsed issuerFirstName: $issuerFirstName, acceptorFirstName: $acceptorFirstName');
      Logger.data(
          '[MEMBER_DATA] Parsed issuer credit rating: ${issuerCreditRating != null ? 'EXISTS' : 'NULL'}');
      Logger.data(
          '[MEMBER_DATA] Parsed acceptor credit rating: ${acceptorCreditRating != null ? 'EXISTS' : 'NULL'}');

      return CredexDetail(
        credexID: action['id']?.toString() ?? '',
        transactionType: details['transactionType']?.toString() ?? '',
        debit: isDebit,
        counterpartyAccountName: counterpartyAccountName ?? '',
        currentUserAccountName: currentUserAccountName,
        counterpartyAccountHandle: counterpartyAccountHandle,
        currentUserAccountHandle: currentUserAccountHandle,
        issuerAccountHandle: issuerAccountHandleRaw,
        acceptorAccountHandle: acceptorAccountHandleRaw,
        issuerAccountName: issuerAccountName,
        acceptorAccountName: acceptorAccountName,
        securerName: null, // Not provided in current API response
        denomination: details['denomination']?.toString() ?? '',
        issuerAccountID: issuerAccountID,
        acceptorAccountID: acceptorAccountID,
        initialAmount: parseAmount(details['initialAmount']?.toString()),
        outstandingAmount: parseAmount(status['outstandingAmount']?.toString()),
        redeemedAmount: parseAmount(status['redeemedAmount']?.toString()),
        defaultedAmount: parseAmount(status['defaultedAmount']?.toString()),
        writtenOffAmount: parseAmount(status['writtenOffAmount']?.toString()),
        formattedInitialAmount: details['initialAmount']?.toString() ?? '',
        formattedOutstandingAmount:
            status['outstandingAmount']?.toString() ?? '',
        formattedRedeemedAmount: status['redeemedAmount']?.toString() ?? '',
        formattedDefaultedAmount: status['defaultedAmount']?.toString() ?? '',
        formattedWrittenOffAmount: status['writtenOffAmount']?.toString() ?? '',
        acceptedAt: parseDate(status['acceptedAt']?.toString()),
        declinedAt: parseDate(status['declinedAt']?.toString()),
        cancelledAt: parseDate(status['cancelledAt']?.toString()),
        dueDate: parseDate(status['dueDate']?.toString()),
        securedCredex: details['securedCredex'] == true,
        clearedAgainst: clearedAgainst
            .map((item) =>
                ClearedTransaction.fromJson(item as Map<String, dynamic>))
            .toList(),
        issuerMemberId: issuerMemberId,
        acceptorMemberId: acceptorMemberId,
        issuerFirstName: issuerFirstName,
        issuerLastName: issuerLastName,
        issuerHandle: issuerHandle,
        issuerTier: issuerTier,
        issuerProfilePicture: issuerProfilePicture,
        issuerCreditRating: issuerCreditRating,
        acceptorFirstName: acceptorFirstName,
        acceptorLastName: acceptorLastName,
        acceptorHandle: acceptorHandle,
        acceptorTier: acceptorTier,
        acceptorProfilePicture: acceptorProfilePicture,
        acceptorCreditRating: acceptorCreditRating,
      );
    } catch (e, stackTrace) {
      Logger.error('Error parsing CredexDetail from API response', e);
      Logger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
