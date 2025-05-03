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
import 'package:vimbisopay_app/presentation/widgets/send_credex/transaction_success_dialog.dart';
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
        String invoiceId = "";
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
          if (state.recipientHandle != _recipientController.text) {
            _recipientController.text = state.recipientHandle ?? '';
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
                              future: widget.databaseHelper.getUser(),
                              builder: (context, snapshot) {
                                String? profileImageUrl;
                                String? memberName;
                                if (snapshot.hasData && 
                                    snapshot.data != null && 
                                    snapshot.data!.dashboard != null) {
                                  profileImageUrl = snapshot.data!.dashboard!.member.profilePictureThumbnail;
                                  memberName = "${snapshot.data!.dashboard!.member.firstname} ${snapshot.data!.dashboard!.member.lastname}";
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
                          // Only request focus for the recipient field when the screen first loads
                          // and not when the user is interacting with other fields
                          Builder(builder: (context) {
                            // Only request focus if we're not already focused on another field
                            // and we're not in the verification process
                            if (state.status != SendCredexStatus.verifyingRecipient && 
                                !_amountFocusNode.hasFocus) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _recipientFocusNode.requestFocus();
                              });
                            }
                            
                            return RecipientInputCard(
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
                            );
                          }),
                        ] else ...[
                          FutureBuilder<User?>(
                            future: widget.databaseHelper.getUser(),
                            builder: (context, snapshot) {
                              String? profileImageUrl;
                              String? memberName;
                              if (snapshot.hasData && 
                                  snapshot.data != null && 
                                  snapshot.data!.dashboard != null) {
                                profileImageUrl = snapshot.data!.dashboard!.member.profilePictureThumbnail;
                                memberName = "${snapshot.data!.dashboard!.member.firstname} ${snapshot.data!.dashboard!.member.lastname}";
                              }
                              
                              return VerifiedRecipientCard(
                                accountDetails: state.verifiedAccountDetails!,
                                onChangeRecipient: () => _bloc.add(const ChangeRecipientEvent()),
                                credexType: state.credexType,
                                profileImageUrl: profileImageUrl,
                                memberName: memberName,
                                isVerifying: state.status == SendCredexStatus.verifyingRecipient,
                                // Pass credit rating data
                                creditRating: snapshot.data?.dashboard?.member.creditRating,
                              );
                            },
                          ),
                        ],
                        
                        // Amount section - always visible but disabled until recipient is verified
                        Container(
                            width: double.infinity,
                            child: FutureBuilder<User?>(
                              future: widget.databaseHelper.getUser(),
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
                                        message: "Upgrade to Hustler10k to increase your daily transaction limit and unlock additional features.",
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
                        Container(
                          width: double.infinity,
                          child: FutureBuilder<User?>(
                            future: widget.databaseHelper.getUser(),
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
                        
                        // Submit button - always visible but disabled until all conditions are met
                        ActionButton(
                          label: 'Sign Offer',
                          onPressed: _canSubmitCredex(state) ? _handleSubmit : null,
                          isLoading: state.isLoading,
                          backgroundColor: _shouldShowWarningColor(state) 
                              ? AppColors.darkRed 
                              : (state.credexType == CredexType.SECURED 
                                  ? AppColors.primary // Gold for Secured
                                  : AppColors.techAzure), // Teal for Unsecured
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
  
  // Determines if the credex can be submitted based on all conditions
  bool _canSubmitCredex(SendCredexState state) {
    // Use the state's canSubmit property which now correctly handles all business rules
    return state.canSubmit;
  }
  
  // Determines if the button should show a warning color
  bool _shouldShowWarningColor(SendCredexState state) {
    if (state.senderAccount == null) return false;
    
    // TRUST accounts can't issue unsecured credexes - show warning
    if (state.senderAccount!.accountType == 'TRUST' && state.credexType == CredexType.UNSECURED) {
      return true;
    }
    
    // For non-TRUST accounts, check if there's insufficient balance for secured credex
    return _hasInsufficientBalance(state);
  }
  
  // Helper method to check if there's insufficient balance for secured Credex
  bool _hasInsufficientBalance(SendCredexState state) {
    // Only check balance for secured Credex on non-TRUST accounts
    if (state.credexType != CredexType.SECURED || 
        state.senderAccount == null || 
        state.senderAccount!.accountType == 'TRUST') {
      return false;
    }
    
    final amount = double.tryParse(state.amount) ?? 0.0;
    return amount > 0 && amount > state.availableBalance;
  }
}
