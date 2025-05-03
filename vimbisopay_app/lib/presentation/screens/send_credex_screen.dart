import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/core/constants/url_constants.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_event.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/index.dart';
import 'package:vimbisopay_app/presentation/widgets/tier_limit_dialog.dart';

class SendCredexScreen extends StatefulWidget {
  static const String routeName = '/send-credex';
  final dashboard.DashboardAccount senderAccount;
  final AccountRepository accountRepository;
  final HomeBloc homeBloc;
  final DatabaseHelper databaseHelper;
  final String? recipientHandle;
  final String? recipientAccountId;

  const SendCredexScreen({
    super.key,
    required this.senderAccount,
    required this.accountRepository,
    required this.homeBloc,
    required this.databaseHelper,
    this.recipientHandle,
    this.recipientAccountId,
  });

  @override
  State<SendCredexScreen> createState() => _SendCredexScreenState();
}

class _SendCredexScreenState extends State<SendCredexScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();
  final _recipientFocusNode = FocusNode();
  late final SendCredexBloc _bloc;
  bool _isAmountFirstEdit = true;
  bool _hasShownUpgradeDialog = false; // Track if we've shown the upgrade dialog
  
  // Cache the user data to avoid multiple database queries
  Future<User?>? _userFuture;

  @override
  void initState() {
    super.initState();
    
    // Initialize the BLoC
    _bloc = SendCredexBloc(
      accountRepository: widget.accountRepository,
      databaseHelper: widget.databaseHelper,
      homeBloc: widget.homeBloc,
    );
    
    // Initialize with sender account and other data
    _bloc.add(InitializeSendCredexEvent(
      senderAccount: widget.senderAccount,
      recipientHandle: widget.recipientHandle,
      recipientAccountId: widget.recipientAccountId,
    ));
    
    // Set up the amount focus listener
    _setupAmountFocusListener();
    
    // Set up the recipient controller
    if (widget.recipientHandle != null) {
      _recipientController.text = widget.recipientHandle!;
    }
    // No automatic focus request - let the user control focus naturally
    
    // Cache the user data to avoid multiple database queries
    _userFuture = widget.databaseHelper.getUser();
    
    // Check if we need to show the upgrade dialog automatically
    _checkAndShowUpgradeDialog();
  }
  
  void _setupAmountFocusListener() {
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus && _isAmountFirstEdit) {
        _amountController.text = '';
        _isAmountFirstEdit = false;
        _bloc.add(UpdateAmountEvent(_amountController.text));
      } else if (!_amountFocusNode.hasFocus) {
        if (_amountController.text.isEmpty) {
          final decimalPlaces = _bloc.state.decimalPlaces;
          _amountController.text = '0.${'0' * decimalPlaces}';
          _isAmountFirstEdit = true;
          _bloc.add(UpdateAmountEvent(_amountController.text));
        } else {
          final amount = double.tryParse(_amountController.text) ?? 0.0;
          _amountController.text = amount.toStringAsFixed(_bloc.state.decimalPlaces);
          _bloc.add(UpdateAmountEvent(_amountController.text));
        }
      }
    });
  }
  
  // Check if we need to show the upgrade dialog automatically for members with memberTier < 3
  void _checkAndShowUpgradeDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = await _userFuture;
      if (user != null && 
          user.dashboard != null && 
          user.dashboard!.member.memberTier < 3) {
        
        // Wait for the bloc state to be fully initialized
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Get the denomination from the bloc state
        final denom = _bloc.state.selectedDenomination.toString().split('.').last;
        
        // Show the upgrade dialog with the remaining daily limit
        if (mounted && !_hasShownUpgradeDialog) {
          _hasShownUpgradeDialog = true; // Prevent showing multiple times
          showDialog(
            context: context,
            builder: (context) => TierLimitDialog(
              message: 'Upgrade to Hustler10k to increase your daily transaction limit and unlock additional features.',
              accountId: widget.senderAccount.accountID,
              homeBloc: widget.homeBloc,
              remainingDailyLimit: user.dashboard!.member.remainingAvailableUSD,
              denomination: denom,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    _recipientFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const ScanQRScreen(showDebugOptions: false),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      // Check if the QR code is in the invoice URL format
      if (result.startsWith(UrlConstants.invoiceUrlPattern) || 
          result.startsWith(UrlConstants.invoiceDeepLinkPattern)) {
        // This is an invoice QR code, extract the invoice ID and navigate to the invoice detail screen
        String invoiceId = '';
        if (result.startsWith(UrlConstants.invoiceUrlPattern)) {
          invoiceId = result.substring(UrlConstants.invoiceUrlPattern.length);
        } else if (result.startsWith(UrlConstants.invoiceDeepLinkPattern)) {
          invoiceId = result.substring(UrlConstants.invoiceDeepLinkPattern.length);
        }
        
        if (invoiceId.isNotEmpty) {
          // Show loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing invoice...'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Navigate to the buyer invoice detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BuyerInvoiceDetailScreen(
                invoiceId: invoiceId,
              ),
            ),
          );
          return;
        }
      }
      
      // Process recipient QR code
      _bloc.add(ScanQRCodeEvent(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _bloc,
      child: BlocConsumer<SendCredexBloc, SendCredexState>(
        listener: (context, state) {
          // Update UI controllers based on state changes
          if (state.amount != _amountController.text && !_amountFocusNode.hasFocus) {
            _amountController.text = state.amount;
          }
          
          // Update recipient controller when handle changes or is cleared
          // Only update if the handle is not empty to preserve partial typing
          if (state.recipientHandle != _recipientController.text && 
              (state.recipientHandle != null && state.recipientHandle!.isNotEmpty)) {
            _recipientController.text = state.recipientHandle!;
          }
          
          // Automatically focus on amount field when verification starts
          if (state.status == SendCredexStatus.verifyingRecipient) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _amountFocusNode.requestFocus();
            });
          }
          
          // Show tier limit dialog if needed
          if (state.status == SendCredexStatus.error && 
              state.errorMessage != null && 
              state.errorMessage!.contains('daily transaction limit')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (context) => TierLimitDialog(
                  message: state.errorMessage!,
                  accountId: widget.senderAccount.accountID,
                  homeBloc: widget.homeBloc,
                ),
              );
            });
          }
          
          // Show success dialog
          if (state.status == SendCredexStatus.success && state.credexResponse != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => TransactionSuccessDialog(
                  response: state.credexResponse!,
                  amount: state.amount,
                  denomination: state.selectedDenomination.toString().split('.').last,
                  homeBloc: widget.homeBloc,
                ),
              );
            });
          }
        },
        builder: (context, state) {
          return WillPopScope(
            onWillPop: () async {
              Navigator.of(context).pop();
              return false;
            },
            child: Scaffold(
              backgroundColor: AppColors.darkBlueDark1,
              appBar: AppBar(
                title: const Text('Offer Credex'),
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              body: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    top: 16.0,
                    left: 16.0,
                    right: 16.0,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sender account card - always visible - moved to the very top as requested
                        if (state.senderAccount != null) ...[
                          SizedBox(
                            width: double.infinity,
                            child: FutureBuilder<User?>(
                              future: _userFuture,
                              builder: (context, snapshot) {
                                String? profileImageUrl;
                                String? memberName;
                                if (snapshot.hasData && 
                                    snapshot.data != null && 
                                    snapshot.data!.dashboard != null) {
                                  profileImageUrl = snapshot.data!.dashboard!.member.profilePictureThumbnail;
                                  memberName = '${snapshot.data!.dashboard!.member.firstname} ${snapshot.data!.dashboard!.member.lastname}';
                                }
                                
                                return SenderAccountCard(
                                  account: state.senderAccount!,
                                  selectedDenomination: state.selectedDenomination,
                                  availableBalance: state.availableBalance,
                                  credexType: state.credexType,
                                  profileImageUrl: profileImageUrl,
                                  memberName: memberName,
                                  // Show secured balance in the sender account card
                                  showSecuredBalance: state.credexType == CredexType.SECURED,
                                  // Pass credit rating data
                                  creditRating: snapshot.data?.dashboard?.member.creditRating,
                                );
                              },
                            ),
                          ),
                        ],
                        
                        // Error messages (status messages will be shown within the recipient card)
                        ErrorMessageWidget(message: state.errorMessage),
                        
                        // Recipient section - always visible
                        // No extra spacing needed here since the previous card already has margin
                        
                        if (state.verifiedAccountDetails == null) ...[
                          // Simplified focus management - no automatic focus requests in the builder
                          RecipientInputCard(
                            recipientController: _recipientController,
                            focusNode: _recipientFocusNode,
                            isVerifying: state.status == SendCredexStatus.verifyingRecipient,
                            onVerify: () => _bloc.add(VerifyRecipientEvent(_recipientController.text)),
                            onScanQR: _scanQRCode,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter recipient handle';
                              }
                              return null;
                            },
                            credexType: state.credexType,
                          ),
                        ] else ...[
                          FutureBuilder<User?>(
                            future: _userFuture,
                            builder: (context, snapshot) {
                              String? profileImageUrl;
                              String? memberName;
                              if (snapshot.hasData && 
                                  snapshot.data != null && 
                                  snapshot.data!.dashboard != null) {
                                profileImageUrl = snapshot.data!.dashboard!.member.profilePictureThumbnail;
                                memberName = '${snapshot.data!.dashboard!.member.firstname} ${snapshot.data!.dashboard!.member.lastname}';
                              }
                              
                              // Convert credit rating data from verifiedAccountDetails if available
                              dashboard.CreditRating? recipientCreditRating;
                              if (state.verifiedAccountDetails!.containsKey('creditRating') && 
                                  state.verifiedAccountDetails!['creditRating'] != null) {
                                final creditRatingData = state.verifiedAccountDetails!['creditRating'] as Map<String, dynamic>;
                                recipientCreditRating = dashboard.CreditRating.fromMap(creditRatingData);
                              }
                              
                              return VerifiedRecipientCard(
                                accountDetails: state.verifiedAccountDetails!,
                                onChangeRecipient: () => _bloc.add(const ChangeRecipientEvent()),
                                credexType: state.credexType,
                                profileImageUrl: profileImageUrl,
                                memberName: memberName,
                                isVerifying: state.status == SendCredexStatus.verifyingRecipient,
                                // Pass recipient's credit rating data from verifiedAccountDetails
                                creditRating: recipientCreditRating,
                              );
                            },
                          ),
                        ],
                        
                        // Amount section - always visible but disabled until recipient is verified
                        SizedBox(
                            width: double.infinity,
                            child: FutureBuilder<User?>(
                              future: _userFuture,
                              builder: (context, snapshot) {
                                // Get member tier and daily limit from user data
                                int? memberTier;
                                double? dailyLimit;
                                
                                if (snapshot.hasData && 
                                    snapshot.data != null && 
                                    snapshot.data!.dashboard != null) {
                                  memberTier = snapshot.data!.dashboard!.member.memberTier;
                                  
                                  // Use remainingAvailableUSD from the dashboard
                                  dailyLimit = snapshot.data!.dashboard!.member.remainingAvailableUSD;
                                }
                                
                                return AmountInputCard(
                                  amountController: _amountController,
                                  amountFocusNode: _amountFocusNode,
                                  selectedDenomination: state.selectedDenomination,
                                  availableDenominations: state.availableDenominations,
                                  onDenominationChanged: (denom) {
                                    if (denom != null) {
                                      // Allow denomination change even while verifying
                                      _bloc.add(UpdateDenominationEvent(denom));
                                    }
                                  },
                                  decimalPlaces: state.decimalPlaces,
                                  onAmountChanged: (value) => _bloc.add(UpdateAmountEvent(value)),
                                  onUpgradePressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => TierLimitDialog(
                                        message: 'Upgrade to Hustler10k to increase your daily transaction limit and unlock additional features.',
                                        accountId: widget.senderAccount.accountID,
                                        homeBloc: widget.homeBloc,
                                      ),
                                    );
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter amount';
                                    }
                                    final amount = double.tryParse(value);
                                    if (amount == null) {
                                      return 'Please enter a valid number';
                                    }
                                    if (amount <= 0) {
                                      return 'Amount must be greater than 0';
                                    }
                                    // Only check balance for secured Credex on non-TRUST accounts
                                    if (state.credexType == CredexType.SECURED && 
                                        state.senderAccount?.accountType != 'TRUST' && 
                                        amount > state.availableBalance) {
                                      return 'Amount exceeds available balance';
                                    }
                                    return null;
                                  },
                                  // Always enable the amount input so it's accessible if tapped
                                  isEnabled: true,
                                  // Always show full content
                                  showFullContent: true,
                                  // Pass credexType to determine border color
                                  isSecured: state.credexType == CredexType.SECURED,
                                  // Pass member tier and daily limit
                                  memberTier: memberTier,
                                  dailyLimit: dailyLimit,
                                );
                              },
                            ),
                          ),
                        
                        // Credex Type Section - moved below the amount section as requested
                        if (state.senderAccount != null)
                        SizedBox(
                          width: double.infinity,
                          child: FutureBuilder<User?>(
                            future: _userFuture,
                            builder: (context, snapshot) {
                              return CredexTypeSection(
                                credexType: state.credexType,
                                onCredexTypeChanged: (credexType) => 
                                    _bloc.add(UpdateCredexTypeEvent(credexType)),
                                dueDate: state.dueDate,
                                onDueDateChanged: (date) => 
                                    _bloc.add(UpdateDueDateEvent(date)),
                                availableBalance: state.availableBalance,
                                selectedDenomination: state.selectedDenomination.toString().split('.').last,
                                accountName: state.senderAccount?.accountName ?? '',
                                // Always enabled
                                isEnabled: true,
                                // Always show full content
                                showFullContent: true,
                                // Pass the amount to display in the type section
                                amount: state.amount,
                              );
                            },
                          ),
                        ),
                        
                        // Add spacing above the Sign Offer button
                        const SizedBox(height: 16),
                        
                        // Display warning message if button is disabled
                        FutureBuilder<User?>(
                          future: _userFuture,
                          builder: (context, snapshot) {
                            // Get member tier and daily limit from user data
                            int? memberTier;
                            double? dailyLimit;
                            
                            if (snapshot.hasData && 
                                snapshot.data != null && 
                                snapshot.data!.dashboard != null) {
                              memberTier = snapshot.data!.dashboard!.member.memberTier;
                              dailyLimit = snapshot.data!.dashboard!.member.remainingAvailableUSD;
                            }
                            
                            final amount = double.tryParse(state.amount) ?? 0.0;
                            final denom = state.selectedDenomination.toString().split('.').last;
                            
                            // Create a list to store warning messages
                            final List<String> warningMessages = [];
                            
                            // Check for daily limit exceeded for memberTier < 3 (applies to both secured and unsecured)
                            if (memberTier != null && memberTier < 3 && dailyLimit != null && amount > dailyLimit) {
                              warningMessages.add('Amount exceeds your daily limit of ${dailyLimit.toStringAsFixed(state.decimalPlaces)} $denom');
                            } 
                            
                            // Check for insufficient secured balance (only applies to secured transactions)
                            if (state.credexType == CredexType.SECURED && 
                                    state.senderAccount?.accountType != 'TRUST' && 
                                    amount > state.availableBalance) {
                              warningMessages.add('Amount exceeds your available secured balance of ${state.availableBalance.toStringAsFixed(state.decimalPlaces)} $denom');
                            }
                            
                            // Display warning messages if needed
                            if (warningMessages.isNotEmpty) {
                              return Column(
                                children: warningMessages.map((message) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8.0),
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppColors.darkRed,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: AppColors.darkRed,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            message,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.darkRed,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            }
                            
                            return const SizedBox.shrink(); // Return empty widget if no warning needed
                          },
                        ),
                        
                        // Submit button - always visible but disabled until all conditions are met
                        FutureBuilder<User?>(
                          future: _userFuture,
                          builder: (context, snapshot) {
                            // Check if we need to disable the button due to daily limit
                            bool canSubmit = _canSubmitCredex(state);
                            
                            // Additional check for daily limit for memberTier < 3
                            if (canSubmit && 
                                snapshot.hasData && 
                                snapshot.data != null && 
                                snapshot.data!.dashboard != null && 
                                snapshot.data!.dashboard!.member.memberTier < 3) {
                              
                              final dailyLimit = snapshot.data!.dashboard!.member.remainingAvailableUSD;
                              final amount = double.tryParse(state.amount) ?? 0.0;
                              
                              if (amount > dailyLimit) {
                                canSubmit = false; // Amount exceeds daily limit
                              }
                            }
                            
                            return ActionButton(
                              label: 'Sign Offer',
                              onPressed: canSubmit ? _handleSubmit : null,
                              isLoading: state.isLoading,
                              backgroundColor: _shouldShowWarningColor(state) 
                                  ? AppColors.darkRed 
                                  : (state.credexType == CredexType.SECURED 
                                      ? AppColors.primary // Gold for Secured
                                      : AppColors.techAzure), // Teal for Unsecured
                            );
                          },
                        ),
                        
                        // Daily Limit display - moved here from AmountInputCard
                        FutureBuilder<User?>(
                          future: _userFuture,
                          builder: (context, snapshot) {
                            // Get member tier and daily limit from user data
                            int? memberTier;
                            double? dailyLimit;
                            
                            if (snapshot.hasData && 
                                snapshot.data != null && 
                                snapshot.data!.dashboard != null) {
                              memberTier = snapshot.data!.dashboard!.member.memberTier;
                              
                              // Use remainingAvailableUSD from the dashboard
                              dailyLimit = snapshot.data!.dashboard!.member.remainingAvailableUSD;
                            }
                            
                            // Only show for memberTier < 3
                            if (memberTier != null && memberTier < 3 && dailyLimit != null) {
                              final denom = state.selectedDenomination.toString().split('.').last;
                              
                              return Container(
                                margin: const EdgeInsets.only(top: 16.0),
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.darkRed, // Red color for daily limit
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Remaining Daily Limit:',
                                          style: TextStyle(
                                            color: AppColors.darkRed, // Red text for daily limit
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${dailyLimit.toStringAsFixed(state.decimalPlaces)} $denom',
                                          style: const TextStyle(
                                            color: AppColors.darkRed, // Red text for daily limit
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'Unlimited transactions: \$1/month',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'Upgrade now and get a full year for \$1 USD',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.green,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => TierLimitDialog(
                                            message: 'Upgrade to Hustler10k to increase your daily transaction limit and unlock additional features.',
                                            accountId: widget.senderAccount.accountID,
                                            homeBloc: widget.homeBloc,
                                            remainingDailyLimit: dailyLimit,
                                            denomination: denom,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.green, // Green color for upgrade button
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'UPGRADE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            return const SizedBox.shrink(); // Return empty widget if conditions not met
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    
    // Dispatch submit event
    _bloc.add(const SendCredexSubmitEvent());
  }
  
  // Determines if the credex can be submitted based on basic conditions
  bool _canSubmitCredex(SendCredexState state) {
    if (!state.canSubmit) return false;
    
    // Check for insufficient secured balance
    final amount = double.tryParse(state.amount) ?? 0.0;
    if (state.credexType == CredexType.SECURED && 
        state.senderAccount?.accountType != 'TRUST' && 
        amount > state.availableBalance) {
      return false;
    }
    
    return true;
  }
  
  // Determines if the button should show a warning color
  bool _shouldShowWarningColor(SendCredexState state) {
    if (state.senderAccount == null) return false;
    
    // TRUST accounts can't issue unsecured credexes - show warning
    if (state.senderAccount!.accountType == 'TRUST' && state.credexType == CredexType.UNSECURED) {
      return true;
    }
    
    // For non-TRUST accounts, check if there's insufficient balance for secured credex
    if (state.credexType == CredexType.SECURED && 
        state.senderAccount?.accountType != 'TRUST') {
      final amount = double.tryParse(state.amount) ?? 0.0;
      return amount > 0 && amount > state.availableBalance;
    }
    
    return false;
  }
}
