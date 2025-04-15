import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_event.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';

class SendCredexBloc extends Bloc<SendCredexEvent, SendCredexState> {
  final AccountRepository accountRepository;
  final DatabaseHelper databaseHelper;
  final HomeBloc homeBloc;
  
  SendCredexBloc({
    required this.accountRepository,
    required this.databaseHelper,
    required this.homeBloc,
  }) : super(const SendCredexState()) {
    on<InitializeSendCredexEvent>(_onInitialize);
    on<VerifyRecipientEvent>(_onVerifyRecipient);
    on<UpdateAmountEvent>(_onUpdateAmount);
    on<UpdateDenominationEvent>(_onUpdateDenomination);
    on<ChangeRecipientEvent>(_onChangeRecipient);
    on<ScanQRCodeEvent>(_onScanQRCode);
    on<SendCredexSubmitEvent>(_onSubmit);
    on<ClearErrorEvent>(_onClearError);
    on<UpdateStatusEvent>(_onUpdateStatus);
    on<UpdateCredexTypeEvent>(_onUpdateCredexType);
    on<UpdateDueDateEvent>(_onUpdateDueDate);
  }
  
  void _onUpdateCredexType(UpdateCredexTypeEvent event, Emitter<SendCredexState> emit) {
    emit(state.copyWith(
      isSecuredCredex: event.isSecured,
      // If switching to secured, clear the due date
      dueDate: event.isSecured ? null : state.dueDate,
    ));
  }
  
  void _onUpdateDueDate(UpdateDueDateEvent event, Emitter<SendCredexState> emit) {
    emit(state.copyWith(
      dueDate: event.dueDate,
    ));
  }
  
  void _onInitialize(InitializeSendCredexEvent event, Emitter<SendCredexState> emit) {
    // Extract available denominations from account balances
    final availableDenominations = _getAvailableDenominations(event.senderAccount);
    
    // Find default denomination
    final defaultDenomination = Denomination.values.firstWhere(
      (d) => d.toString().split('.').last == event.senderAccount.defaultDenom,
      orElse: () => Denomination.USD,
    );
    
    // Initialize state with sender account and default values
    final initialState = state.copyWith(
      status: SendCredexStatus.initial,
      senderAccount: event.senderAccount,
      selectedDenomination: defaultDenomination,
      availableDenominations: availableDenominations,
      amount: '0.${'0' * (defaultDenomination == Denomination.CXX ? 3 : 2)}',
    );
    
    // If recipient info is provided, pre-fill and verify
    if (event.recipientHandle != null && event.recipientAccountId != null) {
      emit(initialState.copyWith(
        recipientHandle: event.recipientHandle,
        recipientAccountId: event.recipientAccountId,
      ));
      
      // Verify the recipient
      add(VerifyRecipientEvent(event.recipientHandle!));
    } else {
      emit(initialState);
    }
  }
  
  List<Denomination> _getAvailableDenominations(dashboard.DashboardAccount account) {
    final Set<String> denomStrs = {};
    
    // Add denominations from securedNetBalancesByDenom
    for (final balance in account.balanceData.securedNetBalancesByDenom) {
      final parts = balance.split(' ');
      if (parts.length >= 2) {
        denomStrs.add(parts.last);
      }
    }
    
    // Add default denomination
    denomStrs.add(account.defaultDenom);
    
    // Convert to Denomination enum values
    return denomStrs.map((denomStr) {
      return Denomination.values.firstWhere(
        (d) => d.toString().split('.').last == denomStr,
        orElse: () => Denomination.USD,
      );
    }).toList();
  }
  
  Future<void> _onVerifyRecipient(VerifyRecipientEvent event, Emitter<SendCredexState> emit) async {
    if (event.handle.isEmpty) return;
    
    emit(state.copyWith(
      status: SendCredexStatus.verifyingRecipient,
      isLoading: true,
      errorMessage: null,
      statusMessage: 'Verifying recipient account...',
    ));
    
    try {
      // Make a direct HTTP request to the API
      final url = '${ApiConfig.baseUrl}/getAccountByHandle';
      final user = await databaseHelper.getUser();
      
      if (user == null) {
        emit(state.copyWith(
          status: SendCredexStatus.error,
          isLoading: false,
          errorMessage: 'Not authenticated',
          statusMessage: null,
        ));
        return;
      }
      
      final headers = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${user.token}',
      };
      
      final body = {'accountHandle': event.handle};
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (!jsonResponse.containsKey('data') ||
            !jsonResponse['data'].containsKey('action') ||
            !jsonResponse['data']['action'].containsKey('details')) {
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: 'Invalid response format',
            statusMessage: null,
          ));
          return;
        }
        
        final details = jsonResponse['data']['action']['details'];
        
        // Extract the fields we need directly from the response
        final accountID = details['accountID'] as String?;
        final accountName = details['accountName'] as String?;
        final accountHandle = details['accountHandle'] as String?;
        
        if (accountID == null || accountName == null || accountHandle == null) {
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: 'Missing required account information',
            statusMessage: null,
          ));
          return;
        }
        
        emit(state.copyWith(
          status: SendCredexStatus.recipientVerified,
          isLoading: false,
          recipientHandle: accountHandle,
          recipientAccountId: accountID,
          verifiedAccountDetails: {
            'accountName': accountName,
            'accountHandle': accountHandle,
          },
          statusMessage: null,
        ));
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to verify recipient account';
        emit(state.copyWith(
          status: SendCredexStatus.error,
          isLoading: false,
          errorMessage: _getFormattedErrorMessage(errorMessage),
          statusMessage: null,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: SendCredexStatus.error,
        isLoading: false,
        errorMessage: _getFormattedErrorMessage(e.toString()),
        statusMessage: null,
      ));
    }
    
    // Clear error message after delay
    Future.delayed(const Duration(seconds: 5), () {
      if (state.errorMessage != null) {
        add(const ClearErrorEvent());
      }
    });
  }
  
  void _onUpdateAmount(UpdateAmountEvent event, Emitter<SendCredexState> emit) {
    emit(state.copyWith(
      amount: event.amount,
    ));
  }
  
  void _onUpdateDenomination(UpdateDenominationEvent event, Emitter<SendCredexState> emit) {
    if (event.denomination != state.selectedDenomination) {
      // Update amount format based on new denomination's decimal places
      final newDecimalPlaces = event.denomination == Denomination.CXX ? 3 : 2;
      String newAmount;
      
      if (state.amount.isNotEmpty && !state.isAmountFirstEdit) {
        final amount = double.tryParse(state.amount) ?? 0.0;
        newAmount = amount.toStringAsFixed(newDecimalPlaces);
      } else {
        newAmount = '0.${'0' * newDecimalPlaces}';
      }
      
      emit(state.copyWith(
        selectedDenomination: event.denomination,
        amount: newAmount,
      ));
    }
  }
  
  void _onChangeRecipient(ChangeRecipientEvent event, Emitter<SendCredexState> emit) {
    // Clear recipient information and reset to initial state for recipient entry
    emit(state.clearRecipient().copyWith(
      status: SendCredexStatus.initial,
      statusMessage: null,
      errorMessage: null
    ));
  }
  
  void _onScanQRCode(ScanQRCodeEvent event, Emitter<SendCredexState> emit) {
    if (event.result == null) return;
    
    // Process recipient QR code (expected format: handle#accountId)
    final parts = event.result!.split('#');
    if (parts.length == 2) {
      final handle = parts[0].startsWith('@') ? parts[0].substring(1) : parts[0];
      
      emit(state.copyWith(
        recipientHandle: handle,
        recipientAccountId: parts[1],
        errorMessage: null,
      ));
      
      // Verify the recipient
      add(VerifyRecipientEvent(handle));
    } else {
      emit(state.copyWith(
        errorMessage: 'Invalid QR code format. Expected format: handle#accountId',
      ));
    }
  }
  
  Future<void> _onSubmit(SendCredexSubmitEvent event, Emitter<SendCredexState> emit) async {
    if (!state.canSubmit) return;
    
    emit(state.copyWith(
      status: SendCredexStatus.submitting,
      isLoading: true,
      errorMessage: null,
      statusMessage: state.isSecuredCredex ? 'Offering Secured Credex...' : 'Offering Unsecured Credex...',
    ));
    
    try {
      final credexRequest = CredexRequest(
        issuerAccountID: state.senderAccount!.accountID,
        receiverAccountID: state.recipientAccountId!,
        denomination: state.selectedDenomination.toString().split('.').last,
        initialAmount: double.parse(state.amount),
        credexType: 'PURCHASE',
        offersOrRequests: 'OFFERS',
        securedCredex: state.isSecuredCredex,
        dueDate: state.isSecuredCredex ? null : state.dueDate?.toIso8601String(),
      );
      
      final result = await accountRepository.createCredex(credexRequest);
      
      await result.fold(
        (failure) async {
          try {
            // Try to parse the error response as JSON
            final Map<String, dynamic> errorResponse = jsonDecode(failure.message ?? failure.toString());
            final action = errorResponse['data']?['action'];
            
            if (action != null && 
                action['details']?['code'] == 'TIER_LIMIT_EXCEEDED') {
              final userMessage = errorResponse['message'] ?? 
                                action['details']?['reason'] ??
                                'You have reached your daily transaction limit.';
              
              emit(state.copyWith(
                status: SendCredexStatus.error,
                isLoading: false,
                errorMessage: userMessage,
                statusMessage: null,
              ));
            } else {
              emit(state.copyWith(
                status: SendCredexStatus.error,
                isLoading: false,
                errorMessage: _getFormattedErrorMessage(failure.message ?? failure.toString()),
                statusMessage: null,
              ));
            }
          } catch (e) {
            emit(state.copyWith(
              status: SendCredexStatus.error,
              isLoading: false,
              errorMessage: _getFormattedErrorMessage(failure.message ?? failure.toString()),
              statusMessage: null,
            ));
          }
        },
        (response) async {
          // Update transactions in database with original response
          await databaseHelper.updatePendingTransactions(response);
          
          emit(state.copyWith(
            status: SendCredexStatus.success,
            isLoading: false,
            statusMessage: null,
            credexResponse: response,
          ));
          
          // Trigger refresh to update dashboard and transactions
          homeBloc.add(const HomeFetchPendingTransactions());
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: SendCredexStatus.error,
        isLoading: false,
        errorMessage: _getFormattedErrorMessage(e.toString()),
        statusMessage: null,
      ));
    }
    
    // Clear error message after delay
    if (state.errorMessage != null) {
      Future.delayed(const Duration(seconds: 5), () {
        add(const ClearErrorEvent());
      });
    }
  }
  
  void _onClearError(ClearErrorEvent event, Emitter<SendCredexState> emit) {
    emit(state.clearError());
  }
  
  void _onUpdateStatus(UpdateStatusEvent event, Emitter<SendCredexState> emit) {
    emit(state.copyWith(
      statusMessage: event.message,
      errorMessage: null,
    ));
  }
  
  String _getFormattedErrorMessage(String error) {
    if (error.toLowerCase().contains('not found')) {
      return 'The recipient account was not found. Please check the handle and try again.';
    } else if (error.toLowerCase().contains('insufficient')) {
      return 'You have insufficient balance to complete this transaction.';
    } else if (error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('timeout')) {
      return 'Unable to complete the transaction due to network issues. Please check your connection and try again.';
    } else if (error.toLowerCase().contains('invalid')) {
      return 'The transaction details are invalid. Please check the amount and recipient handle.';
    } else if (error.toLowerCase().contains('unauthorized')) {
      return 'You are not authorized to perform this transaction. Please log in again.';
    } else {
      return 'Unable to send Credex at this time. Please try again later.';
    }
  }
}
