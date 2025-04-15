import 'package:equatable/equatable.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart';

enum SendCredexStatus {
  initial,
  loading,
  verifyingRecipient,
  recipientVerified,
  submitting,
  success,
  error,
}

class SendCredexState extends Equatable {
  final SendCredexStatus status;
  final dashboard.DashboardAccount? senderAccount;
  final String? recipientHandle;
  final String? recipientAccountId;
  final Map<String, dynamic>? verifiedAccountDetails;
  final Denomination selectedDenomination;
  final List<Denomination> availableDenominations;
  final String amount;
  final String? errorMessage;
  final String? statusMessage;
  final bool isLoading;
  final bool isAmountFirstEdit;
  final CredexResponse? credexResponse;
  
  const SendCredexState({
    this.status = SendCredexStatus.initial,
    this.senderAccount,
    this.recipientHandle,
    this.recipientAccountId,
    this.verifiedAccountDetails,
    this.selectedDenomination = Denomination.USD,
    this.availableDenominations = const [],
    this.amount = '',
    this.errorMessage,
    this.statusMessage,
    this.isLoading = false,
    this.isAmountFirstEdit = true,
    this.credexResponse,
  });
  
  int get decimalPlaces => selectedDenomination == Denomination.CXX ? 3 : 2;
  
  String get defaultAmount => '0.${'0' * decimalPlaces}';
  
  double get availableBalance {
    if (senderAccount == null) return 0.0;
    
    final denom = selectedDenomination.toString().split('.').last;
    
    // For default denomination, use netCredexAssetsInDefaultDenom if no direct balance
    if (denom == senderAccount!.defaultDenom) {
      // Look for direct balance first
      final directBalanceStr = _findBalanceForDenomination(denom);
      final directBalance = _parseBalance(directBalanceStr);
      
      // If direct balance is zero, use netCredexAssetsInDefaultDenom as fallback
      if (directBalance > 0) {
        return directBalance;
      } else {
        // Use netCredexAssetsInDefaultDenom as fallback
        return _parseBalance(senderAccount!.balanceData.netCredexAssetsInDefaultDenom);
      }
    }
    
    // For non-default denominations, find specific balance entry
    final balanceStr = _findBalanceForDenomination(denom);
    return _parseBalance(balanceStr);
  }
  
  // Helper method to find balance for a specific denomination
  String _findBalanceForDenomination(String denom) {
    if (senderAccount == null) return '0.0 $denom';
    
    // Simply match by the denomination suffix, regardless of the format of the number part
    return senderAccount!.balanceData.securedNetBalancesByDenom.firstWhere(
      (balance) => balance.endsWith(' $denom'),
      orElse: () => '0.0 $denom',
    );
  }
  
  // Helper method to parse balance string to double
  double _parseBalance(String balanceStr) {
    // Extract the number part (before the currency code)
    final parts = balanceStr.split(' ');
    if (parts.isEmpty) return 0.0;
    
    // Remove commas and convert to double
    final numberStr = parts.first.replaceAll(',', '');
    return double.tryParse(numberStr) ?? 0.0;
  }
  
  bool get isRecipientVerified => verifiedAccountDetails != null && recipientAccountId != null;
  
  bool get canSubmit => 
      !isLoading && 
      isRecipientVerified && 
      double.tryParse(amount) != null && 
      double.parse(amount) > 0 && 
      double.parse(amount) <= availableBalance;
  
  SendCredexState copyWith({
    SendCredexStatus? status,
    dashboard.DashboardAccount? senderAccount,
    String? recipientHandle,
    String? recipientAccountId,
    Map<String, dynamic>? verifiedAccountDetails,
    Denomination? selectedDenomination,
    List<Denomination>? availableDenominations,
    String? amount,
    String? errorMessage,
    String? statusMessage,
    bool? isLoading,
    bool? isAmountFirstEdit,
    CredexResponse? credexResponse,
  }) {
    return SendCredexState(
      status: status ?? this.status,
      senderAccount: senderAccount ?? this.senderAccount,
      recipientHandle: recipientHandle ?? this.recipientHandle,
      recipientAccountId: recipientAccountId ?? this.recipientAccountId,
      verifiedAccountDetails: verifiedAccountDetails ?? this.verifiedAccountDetails,
      selectedDenomination: selectedDenomination ?? this.selectedDenomination,
      availableDenominations: availableDenominations ?? this.availableDenominations,
      amount: amount ?? this.amount,
      errorMessage: errorMessage,
      statusMessage: statusMessage,
      isLoading: isLoading ?? this.isLoading,
      isAmountFirstEdit: isAmountFirstEdit ?? this.isAmountFirstEdit,
      credexResponse: credexResponse ?? this.credexResponse,
    );
  }
  
  SendCredexState clearRecipient() {
    return copyWith(
      recipientHandle: '',
      recipientAccountId: null,
      verifiedAccountDetails: null,
    );
  }
  
  SendCredexState clearError() {
    return copyWith(
      errorMessage: null,
    );
  }
  
  SendCredexState clearStatus() {
    return copyWith(
      statusMessage: null,
    );
  }
  
  @override
  List<Object?> get props => [
    status,
    senderAccount,
    recipientHandle,
    recipientAccountId,
    verifiedAccountDetails,
    selectedDenomination,
    availableDenominations,
    amount,
    errorMessage,
    statusMessage,
    isLoading,
    isAmountFirstEdit,
    credexResponse,
  ];
}
