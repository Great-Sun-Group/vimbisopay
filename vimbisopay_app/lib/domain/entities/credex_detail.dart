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
  final String? securerName;
  final String denomination;
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

  // Current user credit rating from dashboard
  final CreditRating? currentUserCreditRating;

  CredexDetail({
    required this.credexID,
    required this.transactionType,
    required this.debit,
    required this.counterpartyAccountName,
    this.currentUserAccountName,
    this.securerName,
    required this.denomination,
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
    this.currentUserCreditRating,
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

      // Extract member data from dashboard
      final dashboard = apiData['dashboard'] as Map<String, dynamic>? ?? {};
      final currentUserMember = dashboard['member'] as Map<String, dynamic>?;

      // Extract current user credit rating
      CreditRating? currentUserCreditRating;
      if (currentUserMember != null) {
        final creditRatingData =
            currentUserMember['creditRating'] as Map<String, dynamic>?;
        if (creditRatingData != null) {
          currentUserCreditRating = CreditRating(
            redeemedTotalUSD:
                (creditRatingData['redeemedTotalUSD'] as num?)?.toDouble() ??
                    0.0,
            outstandingTotalUSD:
                (creditRatingData['outstandingTotalUSD'] as num?)?.toDouble() ??
                    0.0,
            defaultedTotalUSD:
                (creditRatingData['defaultedTotalUSD'] as num?)?.toDouble() ??
                    0.0,
            writtenOffTotalUSD:
                (creditRatingData['writtenOffTotalUSD'] as num?)?.toDouble() ??
                    0.0,
          );
        }
      }

      final isDebit = details['amount']?.toString().startsWith('-') ?? false;

      // Simply use the account names from the API as provided
      final currentUserAccountName = details['currentUserAccountName'] as String?;
      final counterpartyAccountName = details['receiverAccountName'] as String?;

      // Debug logging
      Logger.data('Parsing CredexDetail:');
      Logger.data('Dashboard keys: ${dashboard.keys.toList()}');
      Logger.data(
          'Current user member: ${currentUserMember != null ? 'EXISTS' : 'NULL'}');
      if (currentUserMember != null) {
        Logger.data('Member data keys: ${currentUserMember.keys.toList()}');
        Logger.data('Member ID: ${currentUserMember['memberID']}');
        Logger.data('First name: ${currentUserMember['firstname']}');
        Logger.data('Last name: ${currentUserMember['lastname']}');
        Logger.data('Handle: ${currentUserMember['memberHandle']}');
        Logger.data('Tier: ${currentUserMember['memberTier']}');
      }
      Logger.data('Is Debit: $isDebit');
      Logger.data('Action details keys: ${details.keys.toList()}');
      Logger.data('API current user account name: $currentUserAccountName');
      Logger.data('API receiver account name: $counterpartyAccountName');
      Logger.data('Parsed current user account name: $currentUserAccountName');
      Logger.data('Parsed counterparty account name: $counterpartyAccountName');

      // Initialize member data variables
      String? issuerMemberId;
      String? issuerFirstName;
      String? issuerLastName;
      String? issuerHandle;
      int? issuerTier;
      String? issuerProfilePicture;
      CreditRating? issuerCreditRating;

      String? acceptorMemberId;
      String? acceptorFirstName;
      String? acceptorLastName;
      String? acceptorHandle;
      int? acceptorTier;
      String? acceptorProfilePicture;
      CreditRating? acceptorCreditRating;

      // Check if we have enhanced API data (both parties)
      final relationships = dashboard['relationships'] as Map<String, dynamic>?;
      if (relationships != null) {
        // Enhanced API - we have data for both parties
        final issuerData = relationships['issuer'] as Map<String, dynamic>?;
        final acceptorData = relationships['acceptor'] as Map<String, dynamic>?;
        final issuerMember = issuerData?['member'] as Map<String, dynamic>?;
        final acceptorMember = acceptorData?['member'] as Map<String, dynamic>?;

        // Extract issuer data
        if (issuerMember != null) {
          issuerMemberId = issuerMember['memberID']?.toString();
          issuerFirstName = issuerMember['firstname']?.toString();
          issuerLastName = issuerMember['lastname']?.toString();
          issuerHandle = issuerMember['memberHandle']?.toString();
          // Handle memberTier as object with low/high or direct int
          final memberTierData = issuerMember['memberTier'];
          if (memberTierData is Map<String, dynamic>) {
            issuerTier = memberTierData['low'] as int?;
          } else {
            issuerTier = memberTierData as int?;
          }
          issuerProfilePicture = issuerMember['profilePictureUrl']?.toString();

          // Extract issuer credit rating
          final issuerCreditRatingData =
              issuerMember['creditRating'] as Map<String, dynamic>?;
          if (issuerCreditRatingData != null) {
            issuerCreditRating = CreditRating(
              redeemedTotalUSD:
                  (issuerCreditRatingData['redeemedTotalUSD'] as num?)
                          ?.toDouble() ??
                      0.0,
              outstandingTotalUSD:
                  (issuerCreditRatingData['outstandingTotalUSD'] as num?)
                          ?.toDouble() ??
                      0.0,
              defaultedTotalUSD:
                  (issuerCreditRatingData['defaultedTotalUSD'] as num?)
                          ?.toDouble() ??
                      0.0,
              writtenOffTotalUSD:
                  (issuerCreditRatingData['writtenOffTotalUSD'] as num?)
                          ?.toDouble() ??
                      0.0,
            );
          }
        }

        // Extract acceptor data
        if (acceptorMember != null) {
          acceptorMemberId = acceptorMember['memberID']?.toString();
          acceptorFirstName = acceptorMember['firstname']?.toString();
          acceptorLastName = acceptorMember['lastname']?.toString();
          acceptorHandle = acceptorMember['memberHandle']?.toString();
          // Handle memberTier as object with low/high or direct int
          final memberTierData = acceptorMember['memberTier'];
          if (memberTierData is Map<String, dynamic>) {
            acceptorTier = memberTierData['low'] as int?;
          } else {
            acceptorTier = memberTierData as int?;
          }
          acceptorProfilePicture =
              acceptorMember['profilePictureUrl']?.toString();

          // Extract acceptor credit rating
          final acceptorCreditRatingData =
              acceptorMember['creditRating'] as Map<String, dynamic>?;
          if (acceptorCreditRatingData != null) {
            acceptorCreditRating = CreditRating(
              redeemedTotalUSD:
                  (acceptorCreditRatingData['redeemedTotalUSD'] as num?)
                          ?.toDouble() ??
                      0.0,
              outstandingTotalUSD:
                  (acceptorCreditRatingData['outstandingTotalUSD'] as num?)
                          ?.toDouble() ??
                      0.0,
              defaultedTotalUSD:
                  (acceptorCreditRatingData['defaultedTotalUSD'] as num?)
                          ?.toDouble() ??
                      0.0,
              writtenOffTotalUSD:
                  (acceptorCreditRatingData['writtenOffTotalUSD'] as num?)
                          ?.toDouble() ??
                      0.0,
            );
          }
        }
      } else if (currentUserMember != null) {
        // Basic API - only current user data, determine position by transaction direction
        final memberId = currentUserMember['memberID']?.toString();
        final firstName = currentUserMember['firstname']?.toString();
        final lastName = currentUserMember['lastname']?.toString();
        final handle = currentUserMember['memberHandle']?.toString();
        final tier = currentUserMember['memberTier'] as int?;

        if (isDebit) {
          // Current user is issuer (outgoing transaction)
          issuerMemberId = memberId;
          issuerFirstName = firstName;
          issuerLastName = lastName;
          issuerHandle = handle;
          issuerTier = tier;
        } else {
          // Current user is acceptor (incoming transaction)
          acceptorMemberId = memberId;
          acceptorFirstName = firstName;
          acceptorLastName = lastName;
          acceptorHandle = handle;
          acceptorTier = tier;
        }
      }

      return CredexDetail(
        credexID: action['id']?.toString() ?? '',
        transactionType: details['transactionType']?.toString() ?? '',
        debit: isDebit,
        counterpartyAccountName: counterpartyAccountName ?? '',
        currentUserAccountName: currentUserAccountName,
        securerName: null, // Not provided in current API response
        denomination: details['denomination']?.toString() ?? '',
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
        currentUserCreditRating: currentUserCreditRating,
      );
    } catch (e, stackTrace) {
      Logger.error('Error parsing CredexDetail from API response', e);
      Logger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
