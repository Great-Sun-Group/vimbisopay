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
              backgroundColor: AppColors.background,
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
                        // Status and error messages
                        StatusMessageWidget(message: state.statusMessage),
                        ErrorMessageWidget(message: state.errorMessage),
                        
                        // Sender account card - always visible
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
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                        ],
                        
                        // Recipient section - always visible
                        // No extra spacing needed here since the previous card already has margin
                        
                        if (state.verifiedAccountDetails == null) ...[
                          // Only request focus for the recipient field if we're not verifying
                          // This prevents focus from jumping back when user is interacting with amount field
                          Builder(builder: (context) {
                            if (state.status != SendCredexStatus.verifyingRecipient) {
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
                              );
                            },
                          ),
                        ],
                        
                        // Amount section - always visible but disabled until recipient is verified
                        const SizedBox(height: 16),
                        
                        Container(
                          width: double.infinity,
                          child: AmountInputCard(
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
                              // Only check balance for secured Credex
                              if (state.credexType == CredexType.SECURED && amount > state.availableBalance) {
                                return 'Amount exceeds available balance';
                              }
                              return null;
                            },
                            // Enable the amount input as soon as verification starts
                            isEnabled: state.recipientHandle != null && state.recipientHandle!.isNotEmpty,
                            // Show full content when either verifying or verified
                            showFullContent: state.senderAccount != null && 
                                            (state.verifiedAccountDetails != null || 
                                             state.status == SendCredexStatus.verifyingRecipient),
                          ),
                        ),
                        
                        // Credex Type Section - always visible but disabled until recipient is verified
                        const SizedBox(height: 16),
                        
                        Container(
                          width: double.infinity,
                          child: FutureBuilder<User?>(
                            future: widget.databaseHelper.getUser(),
                            builder: (context, snapshot) {
                              // Determine if we should show full content for the Type section
                              // Show full content if handle is being verified or is verified, and amount is entered
                              final hasAmount = double.tryParse(state.amount) != null && double.parse(state.amount) > 0;
                              final isVerifyingOrVerified = state.verifiedAccountDetails != null || 
                                                           state.status == SendCredexStatus.verifyingRecipient;
                              final showFullContent = isVerifyingOrVerified && hasAmount;
                              
                              return CredexTypeSection(
                                credexType: state.credexType,
                                onCredexTypeChanged: (credexType) => 
                                    _bloc.add(UpdateCredexTypeEvent(credexType)),
                                dueDate: state.dueDate,
                                onDueDateChanged: (date) => 
                                    _bloc.add(UpdateDueDateEvent(date)),
                                availableBalance: state.availableBalance,
                                selectedDenomination: state.selectedDenomination.toString().split('.').last,
                                accountName: state.senderAccount!.accountName,
                                // Enable the type section as soon as verification starts
                                isEnabled: state.recipientHandle != null && state.recipientHandle!.isNotEmpty,
                                showFullContent: showFullContent,
                              );
                            },
                          ),
                        ),
                        
                        // Contract and counterparty preview sections - always visible but may be empty
                        const SizedBox(height: 16),
                        
                        Container(
                          width: double.infinity,
                          child: FutureBuilder<User?>(
                            future: widget.databaseHelper.getUser(),
                            builder: (context, snapshot) {
                              String memberName = "You";
                              if (snapshot.hasData && 
                                  snapshot.data != null && 
                                  snapshot.data!.dashboard != null) {
                                memberName = "${snapshot.data!.dashboard!.member.firstname} ${snapshot.data!.dashboard!.member.lastname}";
                              }
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                // Contract section (now includes counterparty preview)
                                ContractSection(
                                  credexType: state.credexType,
                                  amount: state.amount,
                                  denomination: state.selectedDenomination.toString().split('.').last,
                                  senderAccountName: state.senderAccount!.accountName,
                                  recipientAccountName: state.verifiedAccountDetails?['accountName'] ?? 'recipient',
                                  memberName: memberName,
                                  dueDate: state.dueDate,
                                  availableBalance: state.availableBalance,
                                ),
                                ],
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Submit button - always visible but disabled until all conditions are met
                        ActionButton(
                          label: 'Sign Offer',
                          onPressed: state.canSubmit ? _handleSubmit : null,
                          isLoading: state.isLoading,
                          backgroundColor: _hasInsufficientBalance(state) ? AppColors.darkRed : AppColors.primary,
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
  
  // Helper method to check if there's insufficient balance for secured Credex
  bool _hasInsufficientBalance(SendCredexState state) {
    if (state.credexType != CredexType.SECURED) return false;
    
    final amount = double.tryParse(state.amount) ?? 0.0;
    return amount > 0 && amount > state.availableBalance;
  }
}
