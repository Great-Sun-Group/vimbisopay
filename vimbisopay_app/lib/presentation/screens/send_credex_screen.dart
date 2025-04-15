import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_event.dart';
import 'package:vimbisopay_app/presentation/blocs/send_credex/send_credex_state.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/send_credex_widgets.dart';
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
      if (result.startsWith('https://mycredex.app/getInvoice/') || 
          result.startsWith('vimbisopay://invoice/')) {
        // This is an invoice QR code, extract the invoice ID and navigate to the invoice detail screen
        String invoiceId = "";
        if (result.startsWith('https://mycredex.app/getInvoice/')) {
          invoiceId = result.substring('https://mycredex.app/getInvoice/'.length);
        } else if (result.startsWith('vimbisopay://invoice/')) {
          invoiceId = result.substring('vimbisopay://invoice/'.length);
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
                        
                        // Amount and denomination section
                        AmountInputSection(
                          amountController: _amountController,
                          amountFocusNode: _amountFocusNode,
                          selectedDenomination: state.selectedDenomination,
                          availableDenominations: state.availableDenominations,
                          decimalPlaces: state.decimalPlaces,
                          onAmountChanged: (value) => _bloc.add(UpdateAmountEvent(value)),
                          onDenominationChanged: (denom) {
                            if (denom != null) {
                              _bloc.add(UpdateDenominationEvent(denom));
                            }
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
                            if (amount > state.availableBalance) {
                              return 'Amount exceeds available balance';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Recipient section
                        if (state.verifiedAccountDetails == null) ...[
                          // Show search/scan section only when no recipient is verified
                          RecipientInputSection(
                            recipientController: _recipientController,
                            isVerifying: state.status == SendCredexStatus.verifyingRecipient,
                            onVerify: () => _bloc.add(VerifyRecipientEvent(_recipientController.text)),
                            onScanQR: _scanQRCode,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter recipient handle';
                              }
                              return null;
                            },
                          ),
                        ] else ...[
                          // Show verified recipient info with Change button
                          VerifiedRecipientCard(
                            accountDetails: state.verifiedAccountDetails!,
                            onChangeRecipient: () => _bloc.add(const ChangeRecipientEvent()),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // Sender account card
                        if (state.senderAccount != null)
                          SenderAccountCard(
                            account: state.senderAccount!,
                            selectedDenomination: state.selectedDenomination,
                            availableBalance: state.availableBalance,
                          ),
                        
                        const SizedBox(height: 24),
                        
                        // Submit button
                        SubmitButton(
                          isLoading: state.isLoading,
                          isEnabled: state.canSubmit,
                          onPressed: _handleSubmit,
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
}
