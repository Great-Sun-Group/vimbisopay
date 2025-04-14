import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/denomination.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/widgets/tier_limit_dialog.dart';
import 'package:vimbisopay_app/presentation/models/send_credex_arguments.dart';

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

class _SendCredexScreenState extends State<SendCredexScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  late final TextEditingController _amountController;
  final _amountFocusNode = FocusNode();
  late Denomination _selectedDenomination;
  late List<Denomination> _availableDenominations;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAmountFirstEdit = true;
  String? _recipientAccountId;
  String? _statusMessage;
  StreamSubscription? _refreshSubscription;
  late final AnimationController _lottieController;
  late final AudioPlayer _audioPlayer;
  Map<String, dynamic>? _verifiedAccountDetails;
  bool _isVerifyingRecipient = false;

  int get _decimalPlaces => _selectedDenomination == Denomination.CXX ? 3 : 2;

  String get _defaultAmount => '0.${'0' * _decimalPlaces}';

  double get _availableBalance {
    final denom = _selectedDenomination.toString().split('.').last;
    
    // For default denomination, use netCredexAssetsInDefaultDenom if no direct balance
    if (denom == widget.senderAccount.defaultDenom) {
      // Look for direct balance first
      final directBalanceStr = _findBalanceForDenomination(denom);
      final directBalance = _parseBalance(directBalanceStr);
      
      // If direct balance is zero, use netCredexAssetsInDefaultDenom as fallback
      if (directBalance > 0) {
        return directBalance;
      } else {
        // Use netCredexAssetsInDefaultDenom as fallback
        return _parseBalance(widget.senderAccount.balanceData.netCredexAssetsInDefaultDenom);
      }
    }
    
    // For non-default denominations, find specific balance entry
    final balanceStr = _findBalanceForDenomination(denom);
    return _parseBalance(balanceStr);
  }
  
  // Helper method to find balance for a specific denomination
  String _findBalanceForDenomination(String denom) {
    // Simply match by the denomination suffix, regardless of the format of the number part
    return widget.senderAccount.balanceData.securedNetBalancesByDenom.firstWhere(
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

  // Extract available denominations from account balances
  List<Denomination> _getAvailableDenominations() {
    final Set<String> denomStrs = {};
    
    // Add denominations from securedNetBalancesByDenom
    for (final balance in widget.senderAccount.balanceData.securedNetBalancesByDenom) {
      final parts = balance.split(' ');
      if (parts.length >= 2) {
        denomStrs.add(parts.last);
      }
    }
    
    // Add default denomination
    denomStrs.add(widget.senderAccount.defaultDenom);
    
    // Convert to Denomination enum values
    return denomStrs.map((denomStr) {
      return Denomination.values.firstWhere(
        (d) => d.toString().split('.').last == denomStr,
        orElse: () => Denomination.USD,
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _availableDenominations = _getAvailableDenominations();
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
    
    // Check if recipient information is provided in the arguments
    if (widget.recipientHandle != null && widget.recipientAccountId != null) {
      // Pre-fill recipient field and set account ID
      _recipientController.text = widget.recipientHandle!;
      _recipientAccountId = widget.recipientAccountId;
      
      // Log that we're using pre-filled recipient info
      Logger.data('[SEND_CREDEX] Using pre-filled recipient: @${widget.recipientHandle}');
    }
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
      if (_recipientAccountId != null || _verifiedAccountDetails != null) {
        setState(() {
          _recipientAccountId = null;
          _verifiedAccountDetails = null;
        });
      }
    });
  }
  
  void _handleChangeRecipient() {
    setState(() {
      _recipientAccountId = null;
      _verifiedAccountDetails = null;
    });
  }

  void _handleDenominationChange(Denomination? newValue) {
    if (newValue != null && newValue != _selectedDenomination) {
      setState(() {
        _selectedDenomination = newValue;
        // Update amount format based on new denomination's decimal places
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

  void _showError(String message) {
    try {
      // Try to parse the error response as JSON
      final Map<String, dynamic> errorResponse = jsonDecode(message);
      final action = errorResponse['data']?['action'];
      
      if (action != null && 
          action['details']?['code'] == 'TIER_LIMIT_EXCEEDED') {
        final userMessage = errorResponse['message'] ?? 
                          action['details']?['reason'] ??
                          'You have reached your daily transaction limit.';
        
        // Show the tier limit dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (context) => TierLimitDialog(
              message: userMessage,
              accountId: widget.senderAccount.accountID,
              homeBloc: widget.homeBloc,
            ),
          );
        });
        
        setState(() {
          _errorMessage = userMessage;
          _statusMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = _getFormattedErrorMessage(message);
          _statusMessage = null;
        });
      }
    } catch (e) {
      // If JSON parsing fails, fall back to the existing error handling
      setState(() {
        _errorMessage = _getFormattedErrorMessage(message);
        _statusMessage = null;
      });
    }

    // Clear error message after delay
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

  void _updateStatus(String message) {
    setState(() {
      _statusMessage = message;
      _errorMessage = null;
    });
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
      
      // Process recipient QR code (expected format: handle#accountId)
      final parts = result.split('#');
      if (parts.length == 2) {
        final handle =
            parts[0].startsWith('@') ? parts[0].substring(1) : parts[0];
        setState(() {
          _recipientController.text = handle;
          _recipientAccountId = parts[1];
          _errorMessage = null;
        });
      } else {
        // Invalid QR code format
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid QR code format. Expected format: handle#accountId'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _verifyRecipient() async {
    if (_recipientController.text.isEmpty) return;

    setState(() {
      _isVerifyingRecipient = true;
      _errorMessage = null;
      _verifiedAccountDetails = null;
    });

    try {
      _updateStatus('Verifying recipient account...');

      // Make a direct HTTP request to the API
      final url = '${ApiConfig.baseUrl}/getAccountByHandle';
      final user = await widget.databaseHelper.getUser();
      
      if (user == null) {
        _showError('Not authenticated');
        return;
      }
      
      final headers = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${user.token}',
      };
      
      final body = {'accountHandle': _recipientController.text};
      
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
          _showError('Invalid response format');
          return;
        }
        
        final details = jsonResponse['data']['action']['details'];
        
        // Extract the fields we need directly from the response
        final accountID = details['accountID'] as String?;
        final accountName = details['accountName'] as String?;
        final accountHandle = details['accountHandle'] as String?;
        
        if (accountID == null || accountName == null || accountHandle == null) {
          _showError('Missing required account information');
          return;
        }
        
        setState(() {
          _recipientAccountId = accountID;
          _verifiedAccountDetails = {
            'accountName': accountName,
            'accountHandle': accountHandle,
          };
        });
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to verify recipient account';
        _showError(errorMessage);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingRecipient = false;
          _statusMessage = null;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Secured Balances:',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$balance $denom',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
                  _buildStatusMessage(),
                  _buildErrorMessage(),
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
                              borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
                            labelText: 'Denom',
                            labelStyle:
                                const TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          items: _availableDenominations.map((denomination) {
                            return DropdownMenuItem(
                              value: denomination,
                              child: Text(
                                denomination.toString().split('.').last,
                                style:
                                    const TextStyle(color: AppColors.textPrimary),
                              ),
                            );
                          }).toList(),
                          onChanged: null, // Making denom selector read-only
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_verifiedAccountDetails == null) ...[
                    // Show search/scan section only when no recipient is verified
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _recipientController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Recipient 💳 Handle',
                              labelStyle:
                                  const TextStyle(color: AppColors.textSecondary),
                              hintText: 'Enter recipient handle',
                              hintStyle: TextStyle(
                                  color: AppColors.textSecondary.withOpacity(0.5)),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.textSecondary, width: 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              suffixIcon: _isVerifyingRecipient
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
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _recipientController,
                          builder: (context, value, child) {
                            return ElevatedButton(
                              onPressed: value.text.isEmpty || _isVerifyingRecipient
                                  ? null
                                  : _verifyRecipient,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.textPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: const Text('Verify'),
                            );
                          },
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
                  ] else ...[
                    // Show verified recipient info with Change button
                    Card(
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'To',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _handleChangeRecipient,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '💳 ${_verifiedAccountDetails!['accountName']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '💳 ${_verifiedAccountDetails!['accountHandle']}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'From',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '💳 ${widget.senderAccount.accountName}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '💳 ${widget.senderAccount.accountHandle}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildBalanceIndicator(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_isLoading || _verifiedAccountDetails == null) ? null : _handleSubmit,
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
                            'Sign Offer',
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

    // Ensure recipient has been verified
    if (_verifiedAccountDetails == null || _recipientAccountId == null) {
      _showError('Please verify the recipient account first');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _updateStatus('Offering Secured Credex ...');

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
          _showError(failure.message ?? failure.toString());
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
                                  (balance) {
                                    final denom = _selectedDenomination.toString().split('.').last;
                                    return balance.endsWith(' $denom') && 
                                           (balance.startsWith('-') || 
                                            balance.startsWith('+') || 
                                            RegExp(r'^\d').hasMatch(balance));
                                  },
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
