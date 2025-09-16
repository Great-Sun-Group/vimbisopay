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
  bool get canAccept => isPending && transactionType == 'OFFERS' && !debit;
  bool get canDecline => isPending && transactionType == 'OFFERS' && !debit;
  bool get canCancel =>
      isPending &&
      (transactionType == 'OFFERS' || transactionType == 'REQUESTS') &&
      debit;

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

      final isDebit = details['amount']?.toString().startsWith('-') ?? false;

      final issuerAccountID = details['issuerAccountID']?.toString();
      final acceptorAccountID = details['acceptorAccountID']?.toString();

      // Determine account names directly from API (no dashboard ownership logic needed)
      Logger.data('[ACCOUNT_NAMES] Setting account names directly from API details');
      Logger.data('[ACCOUNT_NAMES] details keys: ${details.keys.toList()}');
      Logger.data('[ACCOUNT_NAMES] issuerAccountName raw: ${details['issuerAccountName']}');
      Logger.data('[ACCOUNT_NAMES] acceptorAccountName raw: ${details['acceptorAccountName']}');

      // For now, keep it simple - assign issuer as current user position (this can be refined later)
      final currentUserAccountName = details['issuerAccountName'] as String?;
      final counterpartyAccountName = details['acceptorAccountName'] as String?;
      final currentUserAccountHandle = details['issuerHandle'] as String?;
      final counterpartyAccountHandle = details['acceptorHandle'] as String?;

      Logger.data('[ACCOUNT_NAMES] currentUserAccountName: $currentUserAccountName');
      Logger.data('[ACCOUNT_NAMES] counterpartyAccountName: $counterpartyAccountName');
      Logger.data('Is Debit: $isDebit');
      Logger.data('Action details keys: ${details.keys.toList()}');

      Logger.data('[MEMBER_DATA] Direct parsing from action.details');

      // Extract issuer member data directly from details
      final issuerMemberId = details['issuerMemberID']?.toString();
      final issuerFirstName = details['issuerFirstName']?.toString();
      final issuerLastName = details['issuerLastName']?.toString();
      final issuerHandle = details['issuerHandle']?.toString();

      // Parse issuer tier (object with low/high or direct value)
      int? issuerTier;
      final issuerTierData = details['issuerTier'];
      if (issuerTierData is Map<String, dynamic>) {
        issuerTier = issuerTierData['low'] as int?;
      } else {
        issuerTier = issuerTierData as int?;
      }

      final issuerProfilePicture = details['issuerProfilePicture']?.toString();

      // Parse issuer credit rating
      CreditRating? issuerCreditRating;
      final issuerCreditRatingData = details['issuerCreditRating'] as Map<String, dynamic>?;
      if (issuerCreditRatingData != null) {
        issuerCreditRating = CreditRating(
          redeemedTotalUSD: (issuerCreditRatingData['redeemedTotal'] as num?)?.toDouble() ?? 0.0,
          outstandingTotalUSD: (issuerCreditRatingData['outstandingTotal'] as num?)?.toDouble() ?? 0.0,
          defaultedTotalUSD: (issuerCreditRatingData['defaultedTotal'] as num?)?.toDouble() ?? 0.0,
          writtenOffTotalUSD: (issuerCreditRatingData['writtenOffTotal'] as num?)?.toDouble() ?? 0.0,
        );
      }

      // Extract acceptor member data directly from details
      final acceptorMemberId = details['acceptorMemberID']?.toString();
      final acceptorFirstName = details['acceptorFirstName']?.toString();
      final acceptorLastName = details['acceptorLastName']?.toString();
      final acceptorHandle = details['acceptorHandle']?.toString();

      // Parse acceptor tier (object with low/high or direct value)
      int? acceptorTier;
      final acceptorTierData = details['acceptorTier'];
      if (acceptorTierData is Map<String, dynamic>) {
        acceptorTier = acceptorTierData['low'] as int?;
      } else {
        acceptorTier = acceptorTierData as int?;
      }

      final acceptorProfilePicture = details['acceptorProfilePicture']?.toString();

      // Parse acceptor credit rating
      CreditRating? acceptorCreditRating;
      final acceptorCreditRatingData = details['acceptorCreditRating'] as Map<String, dynamic>?;
      if (acceptorCreditRatingData != null) {
        acceptorCreditRating = CreditRating(
          redeemedTotalUSD: (acceptorCreditRatingData['redeemedTotal'] as num?)?.toDouble() ?? 0.0,
          outstandingTotalUSD: (acceptorCreditRatingData['outstandingTotal'] as num?)?.toDouble() ?? 0.0,
          defaultedTotalUSD: (acceptorCreditRatingData['defaultedTotal'] as num?)?.toDouble() ?? 0.0,
          writtenOffTotalUSD: (acceptorCreditRatingData['writtenOffTotal'] as num?)?.toDouble() ?? 0.0,
        );
      }

      Logger.data('[MEMBER_DATA] Parsed issuerFirstName: $issuerFirstName, acceptorFirstName: $acceptorFirstName');
      Logger.data('[MEMBER_DATA] Parsed issuer credit rating: ${issuerCreditRating != null ? 'EXISTS' : 'NULL'}');
      Logger.data('[MEMBER_DATA] Parsed acceptor credit rating: ${acceptorCreditRating != null ? 'EXISTS' : 'NULL'}');

      return CredexDetail(
        credexID: action['id']?.toString() ?? '',
        transactionType: details['transactionType']?.toString() ?? '',
        debit: isDebit,
        counterpartyAccountName: counterpartyAccountName ?? '',
        currentUserAccountName: currentUserAccountName,
        counterpartyAccountHandle: counterpartyAccountHandle,
        currentUserAccountHandle: currentUserAccountHandle,
        securerName: null, // Not provided in current API response
        denomination: details['denomination']?.toString() ?? '',
        issuerAccountID: details['issuerAccountID']?.toString() ?? '',
        acceptorAccountID: details['acceptorAccountID']?.toString() ?? '',
        initialAmount: parseAmount(details['amount']?.toString()),
        outstandingAmount: parseAmount(status['outstandingAmount']?.toString()),
        redeemedAmount: parseAmount(status['redeemedAmount']?.toString()),
        defaultedAmount: parseAmount(status['defaultedAmount']?.toString()),
        writtenOffAmount: parseAmount(status['writtenOffAmount']?.toString()),
        formattedInitialAmount: details['amount']?.toString() ?? '',
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
