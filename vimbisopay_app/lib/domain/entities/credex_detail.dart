import 'package:vimbisopay_app/core/utils/logger.dart';

enum CredexStatus { 
  pending, 
  accepted, 
  redeemed, 
  cancelled, 
  declined 
}

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
  final String transactionType; // OWES, CLEARED, REQUESTS, OFFERS, DECLINED, CANCELLED
  final bool debit;
  final String counterpartyAccountName;
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

  CredexDetail({
    required this.credexID,
    required this.transactionType,
    required this.debit,
    required this.counterpartyAccountName,
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
        return transactionType == 'OFFERS' ? 'Pending Acceptance' : 'Pending Response';
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
  bool get canCancel => isPending && (transactionType == 'OFFERS' || transactionType == 'REQUESTS') && debit;

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

      return CredexDetail(
        credexID: action['id']?.toString() ?? '',
        transactionType: details['transactionType']?.toString() ?? '',
        debit: details['amount']?.toString().startsWith('-') ?? false,
        counterpartyAccountName: details['receiverAccountName']?.toString() ?? '',
        securerName: null, // Not provided in current API response
        denomination: details['denomination']?.toString() ?? '',
        initialAmount: parseAmount(details['amount']?.toString()),
        outstandingAmount: parseAmount(status['outstandingAmount']?.toString()),
        redeemedAmount: parseAmount(status['redeemedAmount']?.toString()),
        defaultedAmount: parseAmount(status['defaultedAmount']?.toString()),
        writtenOffAmount: parseAmount(status['writtenOffAmount']?.toString()),
        formattedInitialAmount: details['amount']?.toString() ?? '',
        formattedOutstandingAmount: status['outstandingAmount']?.toString() ?? '',
        formattedRedeemedAmount: status['redeemedAmount']?.toString() ?? '',
        formattedDefaultedAmount: status['defaultedAmount']?.toString() ?? '',
        formattedWrittenOffAmount: status['writtenOffAmount']?.toString() ?? '',
        acceptedAt: parseDate(status['acceptedAt']?.toString()),
        declinedAt: parseDate(status['declinedAt']?.toString()),
        cancelledAt: parseDate(status['cancelledAt']?.toString()),
        dueDate: parseDate(status['dueDate']?.toString()),
        securedCredex: details['securedCredex'] == true,
        clearedAgainst: clearedAgainst
            .map((item) => ClearedTransaction.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } catch (e, stackTrace) {
      Logger.error('Error parsing CredexDetail from API response', e);
      Logger.error('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
