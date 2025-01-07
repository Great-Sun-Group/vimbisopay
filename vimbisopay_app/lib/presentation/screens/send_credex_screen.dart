import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

class SendCredexScreen extends StatefulWidget {
  static const String routeName = '/send-credex';
  final dashboard.DashboardAccount senderAccount;
  final AccountRepository accountRepository;
  final HomeBloc homeBloc;
  final DatabaseHelper databaseHelper;

  const SendCredexScreen({
    Key? key,
    required this.senderAccount,
    required this.accountRepository,
    required this.homeBloc,
    required this.databaseHelper,
  }) : super(key: key);

  @override
  State<SendCredexScreen> createState() => _SendCredexScreenState();
}

class _SendCredexScreenState extends State<SendCredexScreen>
    with SingleTickerProviderStateMixin {
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

  double get _availableBalance {
    final denom = _selectedDenomination.toString().split('.').last;
    final balanceStr =
        widget.senderAccount.balanceData.securedNetBalancesByDenom.firstWhere(
      (balance) => balance.contains(denom),
      orElse: () => '0.0 $denom',
    );
    return double.tryParse(balanceStr.split(' ').first) ?? 0.0;
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

  void _handleDenominationChange(Denomination? newValue) {
    if (newValue != null && newValue != _selectedDenomination) {
      setState(() {
        _selectedDenomination = newValue;
        if (_amountController.text.isNotEmpty && !_isAmountFirstEdit) {
          final amount = double.tryParse(_amountController.text) ?? 0.0;
          _amountController.text = amount.toStringAsFixed(_decimalPlaces);
        } else {
          _amountController.text = _defaultAmount;
        }
      });
    }
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
    super.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
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

  void _updateStatus(String message) {
    setState(() {
      _statusMessage = message;
      _errorMessage = null;
    });
  }

  Future<void> _scanQRCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const ScanQRScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      final parts = result.split('#');
      if (parts.length == 2) {
        final handle =
            parts[0].startsWith('@') ? parts[0].substring(1) : parts[0];
        setState(() {
          _recipientController.text = handle;
          _recipientAccountId = parts[1];
          _errorMessage = null;
        });
      }
    }
  }

  Future<bool> _validateRecipient() async {
    if (_recipientAccountId != null) return true;

    setState(() {
      _isValidatingRecipient = true;
      _errorMessage = null;
    });

    try {
      _updateStatus('Validating recipient account...');

      final accountResult = await widget.accountRepository
          .getAccountByHandle(_recipientController.text);

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

  Widget _buildStatusMessage() {
    if (_statusMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.error, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceIndicator() {
    final balance = _availableBalance;
    final denom = _selectedDenomination.toString().split('.').last;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'Available: $balance $denom',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
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
                  _buildStatusMessage(),
                  _buildErrorMessage(),
                  Card(
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'From Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.senderAccount.accountName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '@${widget.senderAccount.accountHandle}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '@',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _recipientController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Recipient Handle',
                            labelStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            hintText: 'Enter recipient handle',
                            hintStyle: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.5)),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            suffixIcon: _isValidatingRecipient
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primary),
                                      ),
                                    ),
                                  )
                                : _recipientAccountId != null
                                    ? const Icon(Icons.check_circle,
                                        color: AppColors.success)
                                    : null,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter recipient handle';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _scanQRCode,
                        icon: const Icon(Icons.qr_code_scanner,
                            color: AppColors.primary),
                        tooltip: 'Scan QR Code',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBalanceIndicator(),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amountController,
                          focusNode: _amountFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            labelStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,' +
                                  _decimalPlaces.toString() +
                                  '}'),
                            ),
                          ],
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
                            if (amount > _availableBalance) {
                              return 'Amount exceeds available balance';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<Denomination>(
                          value: _selectedDenomination,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Currency',
                            labelStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          items: Denomination.values.map((denomination) {
                            return DropdownMenuItem(
                              value: denomination,
                              child: Text(
                                denomination.toString().split('.').last,
                                style:
                                    const TextStyle(color: AppColors.textPrimary),
                              ),
                            );
                          }).toList(),
                          onChanged: _handleDenominationChange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textPrimary),
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

      final result = await widget.accountRepository.createCredex(credexRequest);

      result.fold(
        (failure) {
          _showError(failure.toString());
        },
        (response) async {
          // Map CredexResponse PendingOffer to Dashboard PendingOffer
          final dashboardPendingOffer = dashboard.PendingOffer(
            credexID: response.data.action.id,
            formattedInitialAmount: response.data.action.details.amount,
            counterpartyAccountName:
                response.data.action.details.receiverAccountName,
            secured: response.data.action.details.securedCredex,
          );

          // Update pending transactions in database with mapped data
          // Create PendingData objects with the mapped offer
          const pendingInData = dashboard.PendingData(
            success: true,
            data: [],
            message: 'No pending incoming transactions',
          );

          final pendingOutData = dashboard.PendingData(
            success: true,
            data: [dashboardPendingOffer],
            message: 'Pending outgoing transactions updated',
          );

          // Update transactions in database with original response
          await widget.databaseHelper.updatePendingTransactions(response);

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
                          response.message,
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
                                response
                                    .data.action.details.receiverAccountName,
                              ),
                              const SizedBox(height: 12),
                              _buildTransactionDetailRow(
                                'New Balance',
                                response.data.dashboard.accounts.first
                                    .balanceData.securedNetBalancesByDenom
                                    .firstWhere(
                                  (balance) => balance.contains(
                                      _selectedDenomination
                                          .toString()
                                          .split('.')
                                          .last),
                                  orElse: () =>
                                      '0.0 ${_selectedDenomination.toString().split('.').last}',
                                ),
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
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    AppColors.primary),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Refreshing...',
                                            style: TextStyle(
                                                color: AppColors.textPrimary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst);

                                _refreshSubscription?.cancel();
                                _refreshSubscription =
                                    widget.homeBloc.stream.listen(
                                  (state) {
                                    if (state.status != HomeStatus.loading &&
                                        mounted) {
                                      _refreshSubscription?.cancel();
                                      if (mounted &&
                                          Navigator.canPop(context)) {
                                        Navigator.of(context).pop();
                                      }
                                    } else if (state.status ==
                                            HomeStatus.error &&
                                        mounted) {
                                      _refreshSubscription?.cancel();
                                      if (mounted &&
                                          Navigator.canPop(context)) {
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

                                widget.homeBloc
                                    .add(const HomeFetchPendingTransactions());
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
        },
      );
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
