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

enum CredexType {
  NEUTRAL,  // Neither secured nor unsecured selected yet
  SECURED,
  UNSECURED,
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
  final CredexType credexType;
  final DateTime? dueDate;
  final bool showFullUI; // Controls whether to show the full UI or just the initial input fields
  
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
    this.credexType = CredexType.NEUTRAL,
    this.dueDate,
    this.showFullUI = false, // Default to false - only show initial input fields
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
      double.parse(amount) <= availableBalance &&
      credexType != CredexType.NEUTRAL; // Ensure a Credex type (Secured or Unsecured) is selected
  
  // Helper property to maintain backward compatibility
  bool get isSecuredCredex => credexType == CredexType.SECURED;

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
    CredexType? credexType,
    DateTime? dueDate,
    bool? showFullUI,
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
      credexType: credexType ?? this.credexType,
      dueDate: dueDate,
      showFullUI: showFullUI ?? this.showFullUI,
    );
  }
  
  SendCredexState clearRecipient() {
    return SendCredexState(
      status: status,
      senderAccount: senderAccount,
      selectedDenomination: selectedDenomination,
      availableDenominations: availableDenominations,
      amount: amount,
      isAmountFirstEdit: isAmountFirstEdit,
      credexType: CredexType.NEUTRAL, // Reset to neutral state
      dueDate: dueDate,
      showFullUI: true, // Keep showing the full UI
      // Clear recipient information
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
    credexType,
    dueDate,
    showFullUI,
  ];
}
