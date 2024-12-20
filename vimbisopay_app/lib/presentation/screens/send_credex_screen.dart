import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';

class SendCredexScreen extends StatefulWidget {
  static const String routeName = '/send-credex';
  final DashboardAccount senderAccount;
  final AccountRepository accountRepository;
  final HomeBloc homeBloc;

  const SendCredexScreen({
    Key? key,
    required this.senderAccount,
    required this.accountRepository,
    required this.homeBloc,
  }) : super(key: key);

  @override
  State<SendCredexScreen> createState() => _SendCredexScreenState();
}

class _SendCredexScreenState extends State<SendCredexScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  late final TextEditingController _amountController;
  final _amountFocusNode = FocusNode();
  late Denomination _selectedDenomination;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAmountFirstEdit = true;
  String? _recipientAccountId;
  String? _statusMessage;
  bool _isValidatingRecipient = false;
  StreamSubscription? _refreshSubscription;
  late final AnimationController _lottieController;
  late final AudioPlayer _audioPlayer;

  int get _decimalPlaces => _selectedDenomination == Denomination.CXX ? 3 : 2;
  String get _defaultAmount => '0.${'0' * _decimalPlaces}';

  void _setupAmountFocusListener() {
    _amountFocusNode.addListener(() {
      if (_amountFocusNode.hasFocus && _isAmountFirstEdit) {
        _amountController.text = '';
        _isAmountFirstEdit = false;
      } else if (!_amountFocusNode.hasFocus) {
        if (_amountController.text.isEmpty) {
          _amountController.text = _defaultAmount;
          _isAmountFirstEdit = true;
        } else {
          final amount = double.tryParse(_amountController.text) ?? 0.0;
          _amountController.text = amount.toStringAsFixed(_decimalPlaces);
        }
      }
    });
  }

  void _setupRecipientListener() {
    _recipientController.addListener(() {
      if (_recipientAccountId != null) {
        setState(() {
          _recipientAccountId = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _selectedDenomination = Denomination.values.firstWhere(
      (d) => d.toString().split('.').last == widget.senderAccount.defaultDenom,
      orElse: () => Denomination.USD,
    );
    _amountController = TextEditingController(text: _defaultAmount);
    _setupAmountFocusListener();
    _setupRecipientListener();
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _audioPlayer.dispose();
    if (_refreshSubscription != null) {
      _refreshSubscription!.cancel();
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    }
    _recipientController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = _getFormattedErrorMessage(message);
      _statusMessage = null;
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  String _getFormattedErrorMessage(String error) {
    if (error.toLowerCase().contains('not found')) {
      return 'The recipient account was not found. Please check the handle and try again.';
    } else if (error.toLowerCase().contains('insufficient')) {
      return 'You have insufficient balance to complete this transaction.';
    } else if (error.toLowerCase().contains('network') || error.toLowerCase().contains('timeout')) {
      return 'Unable to complete the transaction due to network issues. Please check your connection and try again.';
    } else if (error.toLowerCase().contains('invalid')) {
      return 'The transaction details are invalid. Please check the amount and recipient handle.';
    } else if (error.toLowerCase().contains('unauthorized')) {
      return 'You are not authorized to perform this transaction. Please log in again.';
    } else {
      return 'Unable to send Credex at this time. Please try again later.';
    }
  }

  void _updateStatus(String message) {
    setState(() {
      _statusMessage = message;
      _errorMessage = null;
    });
  }

  Widget _buildTransactionDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Future<bool> _validateRecipient() async {
    if (_recipientAccountId != null) return true;
    
    setState(() {
      _isValidatingRecipient = true;
      _errorMessage = null;
    });

    try {
      _updateStatus('Validating recipient account...');
      
      final accountResult = await widget.accountRepository.getAccountByHandle(_recipientController.text);
      
      return accountResult.fold(
        (failure) {
          _showError(failure.message ?? 'Failed to validate recipient account');
          return false;
        },
        (account) {
          setState(() {
            _recipientAccountId = account.id;
          });
          return true;
        },
      );
    } catch (e) {
      _showError(e.toString());
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isValidatingRecipient = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Send Credex'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Your existing form widgets here
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                            ),
                          )
                        : const Text(
                            'Send',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!await _validateRecipient()) {
        setState(() => _isLoading = false);
        return;
      }

      _updateStatus('Creating Credex transaction...');

      final credexRequest = CredexRequest(
        issuerAccountID: widget.senderAccount.accountID,
        receiverAccountID: _recipientAccountId!,
        denomination: _selectedDenomination.toString().split('.').last,
        initialAmount: double.parse(_amountController.text),
        credexType: 'PURCHASE',
        offersOrRequests: 'OFFERS',
        securedCredex: true,
      );
      
      // First emit the CreateCredexEvent to update UI state
      widget.homeBloc.add(CreateCredexEvent(credexRequest));
      
      // Listen for state changes
      _refreshSubscription?.cancel();
      _refreshSubscription = widget.homeBloc.stream.listen((state) {
        if (!mounted) return;

        if (state.status == HomeStatus.error) {
          _showError(state.error ?? 'Failed to create transaction');
          _refreshSubscription?.cancel();
          setState(() {
            _isLoading = false;
            _statusMessage = null;
          });
        } else if (state.status == HomeStatus.success && 
                   state.message?.contains('created successfully') == true) {
          _refreshSubscription?.cancel();
          setState(() {
            _isLoading = false;
            _statusMessage = null;
          });
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                _lottieController.forward();
                // Play success sound and trigger haptic feedback
                Future.microtask(() async {
                  HapticFeedback.mediumImpact();
                  await _audioPlayer.play(AssetSource('audio/success.mp3'));
                  await _audioPlayer.setVolume(0.5);
                });
                
                return WillPopScope(
                  onWillPop: () async => false,
                  child: Dialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: Lottie.asset(
                              'assets/animations/success.json',
                              controller: _lottieController,
                              onLoaded: (composition) {
                                _lottieController.duration = composition.duration;
                                _lottieController.forward();
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Transaction Complete',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            state.message ?? 'Transaction completed successfully',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTransactionDetailRow(
                                  'Amount',
                                  '${_amountController.text} ${_selectedDenomination.toString().split('.').last}',
                                ),
                                const SizedBox(height: 12),
                                _buildTransactionDetailRow(
                                  'To',
                                  _recipientController.text,
                                ),
                                const SizedBox(height: 12),
                                _buildTransactionDetailRow(
                                  'New Balance',
                                  state.dashboard?.accounts.first.balanceData.securedNetBalancesByDenom.firstWhere(
                                    (balance) => balance.contains(_selectedDenomination.toString().split('.').last),
                                    orElse: () => '0.0 ${_selectedDenomination.toString().split('.').last}',
                                  ) ?? '0.0 ${_selectedDenomination.toString().split('.').last}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (dialogContext) => WillPopScope(
                                      onWillPop: () async => false,
                                      child: const AlertDialog(
                                        backgroundColor: AppColors.surface,
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'Refreshing...',
                                              style: TextStyle(color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );

                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                  
                                  _refreshSubscription?.cancel();
                                  _refreshSubscription = widget.homeBloc.stream.listen(
                                    (state) {
                                      if (state.status != HomeStatus.loading && mounted) {
                                        _refreshSubscription?.cancel();
                                        if (mounted && Navigator.canPop(context)) {
                                          Navigator.of(context).pop();
                                        }
                                      } else if (state.status == HomeStatus.error && mounted) {
                                        _refreshSubscription?.cancel();
                                        if (mounted && Navigator.canPop(context)) {
                                          Navigator.of(context).pop();
                                        }
                                      }
                                    },
                                    onDone: () {
                                      _refreshSubscription?.cancel();
                                      if (mounted && Navigator.canPop(context)) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    onError: (_) {
                                      _refreshSubscription?.cancel();
                                      if (mounted && Navigator.canPop(context)) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                    cancelOnError: true,
                                  );

                                  // Only refresh to get latest data
                                  widget.homeBloc.add(const HomeRefreshStarted());
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
        }
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }
}
