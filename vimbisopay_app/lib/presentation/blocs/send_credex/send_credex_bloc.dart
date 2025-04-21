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
    DateTime? newDueDate = state.dueDate;
    
    // Set a default due date if switching to UNSECURED and no due date exists
    if (event.credexType == CredexType.UNSECURED && newDueDate == null) {
      newDueDate = DateTime.now().add(const Duration(days: 28));
    }
    
    emit(state.copyWith(
      credexType: event.credexType,
      dueDate: newDueDate,
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
    
    // Set default due date (4 weeks from now)
    final defaultDueDate = DateTime.now().add(const Duration(days: 28));
    
    // Initialize state with sender account and default values
    final initialState = state.copyWith(
      status: SendCredexStatus.initial,
      senderAccount: event.senderAccount,
      selectedDenomination: defaultDenomination,
      availableDenominations: availableDenominations,
      amount: '0.${'0' * (defaultDenomination == Denomination.CXX ? 3 : 2)}',
      showFullUI: false, // Start with only showing initial input fields
      credexType: CredexType.SECURED, // Explicitly set to secured state on initialization
      dueDate: defaultDueDate, // Set default due date
    );
    
    // If recipient info is provided, pre-fill and verify
    if (event.recipientHandle != null && event.recipientAccountId != null) {
      // Check if sender's account handle equals recipient's handle
      if (event.senderAccount.accountHandle.toLowerCase() == event.recipientHandle!.toLowerCase()) {
        emit(initialState.copyWith(
          status: SendCredexStatus.error,
          isLoading: false,
          errorMessage: 'Offer account must be different than recipient account.',
          statusMessage: null,
        ));
        
        // Clear error message after delay
        Future.delayed(const Duration(seconds: 5), () {
          if (state.errorMessage != null) {
            add(const ClearErrorEvent());
          }
        });
        
        return;
      }
      
      // If we have both handle and ID, we can consider this pre-verified
      // but we'll still verify it with the API to get the account name
      emit(initialState.copyWith(
        recipientHandle: event.recipientHandle,
        recipientAccountId: event.recipientAccountId,
        // Set temporary verified account details until API verification completes
        verifiedAccountDetails: {
          'accountHandle': event.recipientHandle,
          'accountName': 'Verifying...',
        },
        status: SendCredexStatus.recipientVerified,
        showFullUI: true, // Show the full UI immediately for pre-filled recipients
        // Preserve the current credexType and dueDate
        credexType: state.credexType,
        dueDate: state.dueDate,
      ));
      
      // Still verify the recipient to get the account name and confirm the account exists
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
    
    // Check if sender's account handle equals recipient's handle
    if (state.senderAccount != null && 
        state.senderAccount!.accountHandle.toLowerCase() == event.handle.toLowerCase()) {
      emit(state.copyWith(
        status: SendCredexStatus.error,
        isLoading: false,
        errorMessage: 'Offer account must be different than recipient account.',
        statusMessage: null,
      ));
      
      // Clear error message after delay
      Future.delayed(const Duration(seconds: 5), () {
        if (state.errorMessage != null) {
          add(const ClearErrorEvent());
        }
      });
      
      return;
    }
    
    // Update state to show we're verifying and set recipientHandle
    // This allows the UI to show and enable the Amount section while verification is in progress
    emit(state.copyWith(
      status: SendCredexStatus.verifyingRecipient,
      isLoading: true,
      errorMessage: null,
      statusMessage: 'Verifying recipient account...',
      recipientHandle: event.handle,
      showFullUI: true, // Show the full UI immediately when verification starts
    ));
    
    try {
      // Make a direct HTTP request to the API
      final url = '${ApiConfig.baseUrl}/getAccountByHandle';
      Logger.data('Verifying recipient: ${event.handle}, URL: $url');
      
      final user = await databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('User is null, not authenticated');
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
      Logger.data('Request body: ${json.encode(body)}');
      
      Logger.data('Sending API request to verify recipient');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(body),
      );
      
      Logger.data('API response status code: ${response.statusCode}');
      Logger.data('API response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        Logger.data('Parsed JSON response: $jsonResponse');
        
        if (!jsonResponse.containsKey('data') ||
            !jsonResponse['data'].containsKey('action') ||
            !jsonResponse['data']['action'].containsKey('details')) {
          Logger.error('Invalid response format: $jsonResponse');
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: 'Invalid response format',
            statusMessage: null,
          ));
          return;
        }
        
        final details = jsonResponse['data']['action']['details'];
        Logger.data('Response details: $details');
        
        // Extract the fields we need directly from the response
        final accountID = details['accountID'] as String?;
        final accountName = details['accountName'] as String?;
        final accountHandle = details['accountHandle'] as String?;
        
        if (accountID == null || accountName == null || accountHandle == null) {
          Logger.error('Missing required account information: accountID=$accountID, accountName=$accountName, accountHandle=$accountHandle');
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: 'Missing required account information',
            statusMessage: null,
          ));
          return;
        }
        
        Logger.data('Recipient verified successfully: $accountHandle ($accountID)');
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
          showFullUI: true, // Show the full UI after successful verification
          // Explicitly preserve the current credexType and dueDate
          credexType: state.credexType,
          dueDate: state.dueDate,
        ));
      } else if (response.statusCode == 401 || 
                (response.statusCode == 400 && response.body.toLowerCase().contains('token expired'))) {
        // Token expired, try to refresh it
        Logger.data('Token expired, attempting to refresh');
        
        try {
          // Get the current user to get phone and passwordHash
          final user = await databaseHelper.getUser();
          
          if (user == null || user.passwordHash == null) {
            Logger.error('No user or password hash found for token refresh');
            emit(state.copyWith(
              status: SendCredexStatus.error,
              isLoading: false,
              errorMessage: 'Authentication error. Please log in again.',
              statusMessage: null,
            ));
            return;
          }
          
          // Use the account repository to refresh the token with loginV2
          final refreshResult = await accountRepository.loginV2(
            phone: user.phone,
            passwordHash: user.passwordHash,
          );
          
          // Handle the refresh result
          if (refreshResult.isLeft()) {
            // Failed to refresh token
            final failure = refreshResult.fold((l) => l, (r) => null);
            Logger.error('Failed to refresh token: ${failure?.message}');
            emit(state.copyWith(
              status: SendCredexStatus.error,
              isLoading: false,
              errorMessage: 'Authentication error. Please log in again.',
              statusMessage: null,
            ));
            return;
          }
          
          // Token refresh succeeded
          final refreshedUser = refreshResult.fold((l) => null, (r) => r);
          if (refreshedUser == null) {
            // No user found
            Logger.error('No user found after token refresh');
            emit(state.copyWith(
              status: SendCredexStatus.error,
              isLoading: false,
              errorMessage: 'Authentication error. Please log in again.',
              statusMessage: null,
            ));
            return;
          }
          
          // Save the refreshed user
          await accountRepository.saveUser(refreshedUser);
        } catch (e) {
          Logger.error('Exception during token refresh: $e');
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: 'Authentication error. Please log in again.',
            statusMessage: null,
          ));
          return;
        }
        
        // Get the updated user with the new token
        final updatedUserResult = await accountRepository.getCurrentUser();
        final updatedUser = updatedUserResult.fold((l) => null, (r) => r);
        
        if (updatedUser == null) {
          Logger.error('No updated user found after token refresh');
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: 'Authentication error. Please log in again.',
            statusMessage: null,
          ));
          return;
        }
        
        // Try the request again with the refreshed token
        Logger.data('Token refreshed, retrying request');
        
        final newHeaders = {
          'Content-Type': 'application/json',
          'x-client-api-key': ApiConfig.apiKey,
          'Authorization': 'Bearer ${updatedUser.token}',
        };
        
        final retryResponse = await http.post(
          Uri.parse(url),
          headers: newHeaders,
          body: json.encode(body),
        );
        
        Logger.data('Retry response status code: ${retryResponse.statusCode}');
        Logger.data('Retry response body: ${retryResponse.body}');
        
        if (retryResponse.statusCode == 200) {
          final jsonResponse = json.decode(retryResponse.body);
          
          if (!jsonResponse.containsKey('data') ||
              !jsonResponse['data'].containsKey('action') ||
              !jsonResponse['data']['action'].containsKey('details')) {
            Logger.error('Invalid response format after token refresh: $jsonResponse');
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
            Logger.error('Missing required account information after token refresh');
            emit(state.copyWith(
              status: SendCredexStatus.error,
              isLoading: false,
              errorMessage: 'Missing required account information',
              statusMessage: null,
            ));
            return;
          }
          
          Logger.data('Recipient verified successfully after token refresh: $accountHandle ($accountID)');
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
            showFullUI: true, // Show the full UI after successful verification
            // Explicitly preserve the current credexType and dueDate
            credexType: state.credexType,
            dueDate: state.dueDate,
          ));
        } else {
          // Still failed after token refresh
          final errorMessage = json.decode(retryResponse.body)['message'] ?? 'Failed to verify recipient account';
          Logger.error('Error verifying recipient after token refresh: $errorMessage');
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: _getFormattedErrorMessage(errorMessage),
            statusMessage: null,
          ));
        }
      } else {
        try {
          final jsonResponse = json.decode(response.body);
          final message = jsonResponse['message'] ?? 'Failed to verify recipient account';
          
          // Check for specific account not found error
          if (jsonResponse.containsKey('data') && 
              jsonResponse['data'].containsKey('action') && 
              jsonResponse['data']['action'].containsKey('details')) {
            
            final details = jsonResponse['data']['action']['details'];
            if (details['code'] == 'ACCOUNT_NOT_FOUND') {
              emit(state.copyWith(
                status: SendCredexStatus.error,
                isLoading: false,
                errorMessage: 'Account not found. Please check the handle and try again.',
                statusMessage: null,
              ));
              return;
            }
          }
          
          Logger.error('Error verifying recipient: $message');
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: _getFormattedErrorMessage(message),
            statusMessage: null,
          ));
        } catch (e) {
          final errorMessage = 'Failed to verify recipient account';
          Logger.error('Error parsing response: $e');
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: errorMessage,
            statusMessage: null,
          ));
        }
      }
    } catch (e) {
      Logger.error('Exception during recipient verification: $e');
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
      // Explicitly preserve the due date when updating amount
      dueDate: state.dueDate,
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
        // Explicitly preserve the due date when updating denomination
        dueDate: state.dueDate,
      ));
    }
  }
  
  void _onChangeRecipient(ChangeRecipientEvent event, Emitter<SendCredexState> emit) {
    // Create a new state with cleared recipient information and reset to secured credex type
    final newState = SendCredexState(
      status: SendCredexStatus.initial,
      senderAccount: state.senderAccount,
      selectedDenomination: state.selectedDenomination,
      availableDenominations: state.availableDenominations,
      amount: state.amount,
      isAmountFirstEdit: state.isAmountFirstEdit,
      credexType: CredexType.SECURED, // Reset to secured state
      dueDate: state.dueDate,
      showFullUI: true, // Keep showing the full UI
      // Explicitly clear recipient information
      recipientHandle: '',
      recipientAccountId: null,
      verifiedAccountDetails: null,
    );
    
    // Emit the new state
    emit(newState);
  }
  
  void _onScanQRCode(ScanQRCodeEvent event, Emitter<SendCredexState> emit) {
    if (event.result == null) return;
    
    // Process recipient QR code (expected format: handle#accountId)
    final parts = event.result!.split('#');
    if (parts.length == 2) {
      final handle = parts[0].startsWith('@') ? parts[0].substring(1) : parts[0];
      final accountId = parts[1];
      
      // Check if sender's account handle equals recipient's handle
      if (state.senderAccount != null && 
          state.senderAccount!.accountHandle.toLowerCase() == handle.toLowerCase()) {
        emit(state.copyWith(
          status: SendCredexStatus.error,
          isLoading: false,
          errorMessage: 'Offer account must be different than recipient account.',
          statusMessage: null,
        ));
        
        // Clear error message after delay
        Future.delayed(const Duration(seconds: 5), () {
          if (state.errorMessage != null) {
            add(const ClearErrorEvent());
          }
        });
        
        return;
      }
      
      // If we have both handle and ID from QR code, we can consider this pre-verified
      // but we'll still verify it with the API to get the account name
      emit(state.copyWith(
        recipientHandle: handle,
        recipientAccountId: accountId,
        // Set temporary verified account details until API verification completes
        verifiedAccountDetails: {
          'accountHandle': handle,
          'accountName': 'Verifying...',
        },
        status: SendCredexStatus.recipientVerified,
        showFullUI: true, // Show the full UI immediately for QR code scanned recipients
        errorMessage: null,
        // Explicitly preserve the current credexType and dueDate
        credexType: state.credexType,
        dueDate: state.dueDate,
      ));
      
      // Still verify the recipient to get the account name and confirm the account exists
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
      statusMessage: state.credexType == CredexType.SECURED ? 'Offering Secured Credex...' : 'Offering Unsecured Credex...',
    ));
    
    try {
      final credexRequest = CredexRequest(
        issuerAccountID: state.senderAccount!.accountID,
        receiverAccountID: state.recipientAccountId!,
        denomination: state.selectedDenomination.toString().split('.').last,
        initialAmount: double.parse(state.amount),
        credexType: 'PURCHASE',
        offersOrRequests: 'OFFERS',
        securedCredex: state.credexType == CredexType.SECURED,
        dueDate: state.credexType == CredexType.SECURED ? null : state.dueDate?.toIso8601String(),
      );
      
      final result = await accountRepository.createCredex(credexRequest);
      
      // Handle failure case
      if (result.isLeft()) {
        final failure = result.fold((l) => l, (r) => null);
        
        // Check if the error is due to token expiration
        final errorMessage = failure?.message ?? '';
        if (errorMessage.toLowerCase().contains('token expired') || 
            errorMessage.toLowerCase().contains('unauthorized')) {
          Logger.data('Token expired during submit, attempting to refresh');
          
          try {
            // Get the current user to get phone and passwordHash
            final user = await databaseHelper.getUser();
            
            if (user == null || user.passwordHash == null) {
              Logger.error('No user or password hash found for token refresh');
              emit(state.copyWith(
                status: SendCredexStatus.error,
                isLoading: false,
                errorMessage: 'Authentication error. Please log in again.',
                statusMessage: null,
                dueDate: state.dueDate, // Preserve due date
              ));
              return;
            }
            
            // Use the account repository to refresh the token with loginV2
            final refreshResult = await accountRepository.loginV2(
              phone: user.phone,
              passwordHash: user.passwordHash,
            );
            
            // Handle the refresh result
            if (refreshResult.isLeft()) {
              // Failed to refresh token
              final refreshFailure = refreshResult.fold((l) => l, (r) => null);
              Logger.error('Failed to refresh token: ${refreshFailure?.message}');
              emit(state.copyWith(
                status: SendCredexStatus.error,
                isLoading: false,
                errorMessage: 'Authentication error. Please log in again.',
                statusMessage: null,
                dueDate: state.dueDate, // Preserve due date
              ));
              return;
            }
            
            // Token refresh succeeded
            final refreshedUser = refreshResult.fold((l) => null, (r) => r);
            if (refreshedUser == null) {
              // No user found
              Logger.error('No user found after token refresh');
              emit(state.copyWith(
                status: SendCredexStatus.error,
                isLoading: false,
                errorMessage: 'Authentication error. Please log in again.',
                statusMessage: null,
              ));
              return;
            }
            
            // Save the refreshed user
            await accountRepository.saveUser(refreshedUser);
            
            // Try the request again with the refreshed token
            Logger.data('Token refreshed, retrying createCredex request');
            final retryResult = await accountRepository.createCredex(credexRequest);
            
            if (retryResult.isLeft()) {
              // Still failed after token refresh
              final retryFailure = retryResult.fold((l) => l, (r) => null);
              try {
                // Try to parse the error response as JSON
                final Map<String, dynamic> errorResponse = jsonDecode(retryFailure?.message ?? retryFailure.toString());
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
                    dueDate: state.dueDate, // Preserve due date
                  ));
                } else {
                  emit(state.copyWith(
                    status: SendCredexStatus.error,
                    isLoading: false,
                    errorMessage: _getFormattedErrorMessage(retryFailure?.message ?? retryFailure.toString()),
                    statusMessage: null,
                  ));
                }
              } catch (e) {
                emit(state.copyWith(
                  status: SendCredexStatus.error,
                  isLoading: false,
                  errorMessage: _getFormattedErrorMessage(retryFailure?.message ?? retryFailure.toString()),
                  statusMessage: null,
                ));
              }
              return;
            }
            
            // Handle success case after token refresh
            final response = retryResult.fold((l) => null, (r) => r);
            if (response != null) {
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
            }
            return;
          } catch (e) {
            Logger.error('Exception during token refresh in submit: $e');
            emit(state.copyWith(
              status: SendCredexStatus.error,
              isLoading: false,
              errorMessage: 'Authentication error. Please log in again.',
              statusMessage: null,
              dueDate: state.dueDate, // Preserve due date
            ));
            return;
          }
        }
        
        // Handle other errors (not token related)
        try {
          // Try to parse the error response as JSON
          final Map<String, dynamic> errorResponse = jsonDecode(failure?.message ?? failure.toString());
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
              dueDate: state.dueDate, // Preserve due date
            ));
          } else {
            emit(state.copyWith(
              status: SendCredexStatus.error,
              isLoading: false,
              errorMessage: _getFormattedErrorMessage(failure?.message ?? failure.toString()),
              statusMessage: null,
              dueDate: state.dueDate, // Preserve due date
            ));
          }
        } catch (e) {
          emit(state.copyWith(
            status: SendCredexStatus.error,
            isLoading: false,
            errorMessage: _getFormattedErrorMessage(failure?.message ?? failure.toString()),
            statusMessage: null,
            dueDate: state.dueDate, // Preserve due date
          ));
        }
        return;
      }
      
      // Handle success case
      final response = result.fold((l) => null, (r) => r);
      if (response != null) {
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
      }
    } catch (e) {
      emit(state.copyWith(
        status: SendCredexStatus.error,
        isLoading: false,
        errorMessage: _getFormattedErrorMessage(e.toString()),
        statusMessage: null,
        dueDate: state.dueDate, // Preserve due date
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
    // Use copyWith instead of clearError to ensure we preserve the due date
    emit(state.copyWith(
      errorMessage: null,
      dueDate: state.dueDate,
    ));
  }
  
  void _onUpdateStatus(UpdateStatusEvent event, Emitter<SendCredexState> emit) {
    emit(state.copyWith(
      statusMessage: event.message,
      errorMessage: null,
      // Explicitly preserve the due date
      dueDate: state.dueDate,
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
