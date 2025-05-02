import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';

/// A screen that allows buyers to pay for invoices.
///
/// This screen is shown after a buyer views an invoice and decides to pay.
/// It allows the buyer to select a Credex account and pay for the invoice.
class PaymentScreen extends StatefulWidget {
  /// The invoice to pay.
  final Invoice invoice;

  /// Creates a new [PaymentScreen] instance.
  const PaymentScreen({
    super.key,
    required this.invoice,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  final AccountRepository _accountRepository = ServiceLocator.accountRepository;
  
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String? _errorMessage;
  List<DashboardAccount> _accounts = [];
  DashboardAccount? _selectedAccount;
  String? _memberId;

  @override
  void initState() {
    super.initState();
    Logger.data('[PAYMENT_SCREEN] Initializing payment screen');
    _loadAccounts();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    Logger.data('[PAYMENT_SCREEN] Loading accounts');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });


    try {
      // Load user's accounts directly from the dashboard
      // This already uses DatabaseHelper internally to get the current user
      final dashboardResult = await _accountRepository.getCurrentUser();
      
      dashboardResult.fold(
        (failure) {
          Logger.error('[PAYMENT_SCREEN] Failed to load accounts', failure);
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load accounts';
          });
        },
        (user) {
          if (user == null) {
            Logger.error('[PAYMENT_SCREEN] User not found from repository');
            setState(() {
              _isLoading = false;
              _errorMessage = 'User not found';
            });
            return;
          }
          
          // Get accounts from user's dashboard
          final accounts = user.dashboard?.accounts ?? [];
          Logger.data('[PAYMENT_SCREEN] Found ${accounts.length} accounts');
          
          // Set the member ID from the user
          _memberId = user.memberId;
          Logger.data('[PAYMENT_SCREEN] User memberId: $_memberId');
          
          // Filter for accounts with the same currency as the invoice
          final filteredAccounts = accounts.where((account) {
            return account.defaultDenom == widget.invoice.currency;
          }).toList();
          
          Logger.data('[PAYMENT_SCREEN] Found ${filteredAccounts.length} accounts with currency ${widget.invoice.currency}');
          
          setState(() {
            _isLoading = false;
            _accounts = filteredAccounts;
            
            // Select the first account by default if available
            if (filteredAccounts.isNotEmpty) {
              _selectedAccount = filteredAccounts.first;
            }
          });
        },
      );
    } catch (e) {
      Logger.error('[PAYMENT_SCREEN] Unexpected error loading accounts', e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }


  bool _hasSufficientBalance() {
    if (_selectedAccount == null) return false;
    
    final balanceStr = _getFormattedBalance();
    Logger.data('[PAYMENT_SCREEN] Checking balance: $balanceStr');
    
    try {
      // Extract the number part using regex that includes commas
      final match = RegExp(r'([0-9,]+\.?[0-9]*)').firstMatch(balanceStr);
      if (match == null) {
        Logger.error('[PAYMENT_SCREEN] Could not extract number from balance: $balanceStr');
        return false;
      }
      
      // Get the full number string including commas
      final numberWithCommas = match.group(1)!;
      Logger.data('[PAYMENT_SCREEN] Extracted number with commas: $numberWithCommas');
      
      // Remove commas and convert to double
      final balance = double.tryParse(numberWithCommas.replaceAll(',', '')) ?? 0.0;
      final required = widget.invoice.totalAmount / 100.0;
      
      Logger.data('[PAYMENT_SCREEN] Balance (after removing commas): $balance');
      Logger.data('[PAYMENT_SCREEN] Required amount: $required');
      
      return balance >= required;
    } catch (e) {
      Logger.error('[PAYMENT_SCREEN] Error checking balance', e);
      return false;
    }
  }

  void _showInsufficientBalanceError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insufficient Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your selected account doesn\'t have enough Credex to complete this payment.'),
            const SizedBox(height: 16),
            Text('Required: ${widget.invoice.formattedTotalAmount}'),
            Text('Available: ${_getFormattedBalance()}'),
            const SizedBox(height: 16),
            const Text('Please select a different account or add funds to your account.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getAccountBalance(DashboardAccount account) {
    final denom = widget.invoice.currency;
    
    // Log all available balances for debugging
    Logger.data('[PAYMENT_SCREEN] Getting balance for account: ${account.accountName}');
    Logger.data('[PAYMENT_SCREEN] Secured balances: ${account.balanceData.securedNetBalancesByDenom}');
    Logger.data('[PAYMENT_SCREEN] Net assets: ${account.balanceData.netCredexAssetsInDefaultDenom}');
    
    // First try to find the balance in securedNetBalancesByDenom
    String? balanceStr;
    try {
      // Log all balances for debugging
      for (final balance in account.balanceData.securedNetBalancesByDenom) {
        Logger.data('[PAYMENT_SCREEN] Checking balance string: "$balance"');
      }
      
      // Try exact match first
      balanceStr = account.balanceData.securedNetBalancesByDenom.firstWhere(
        (balance) => balance.endsWith(' $denom'),
        orElse: () => '',
      );
      Logger.data('[PAYMENT_SCREEN] After exact match: "$balanceStr"');
      
      // If no exact match, try case-insensitive match
      if (balanceStr.isEmpty) {
        balanceStr = account.balanceData.securedNetBalancesByDenom.firstWhere(
          (balance) => balance.toLowerCase().endsWith(' ${denom.toLowerCase()}'),
          orElse: () => '',
        );
        Logger.data('[PAYMENT_SCREEN] After case-insensitive match: "$balanceStr"');
      }
      
      // If still no match, try matching just the number part
      if (balanceStr.isEmpty) {
        balanceStr = account.balanceData.securedNetBalancesByDenom.firstWhere(
          (balance) => balance.contains(RegExp(r'[0-9]')),
          orElse: () => '',
        );
        Logger.data('[PAYMENT_SCREEN] After number match: "$balanceStr"');
        
        if (balanceStr.isNotEmpty) {
          // Extract the full number including commas and decimals
          final match = RegExp(r'([0-9,]+\.?[0-9]*)').firstMatch(balanceStr);
          Logger.data('[PAYMENT_SCREEN] Regex match: ${match?.group(1) ?? 'no match'}');
          
          if (match != null) {
            final numberWithCommas = match.group(1)!;
            Logger.data('[PAYMENT_SCREEN] Extracted number with commas: $numberWithCommas');
            balanceStr = '$numberWithCommas $denom';
          } else {
            balanceStr = '';
          }
        }
      }
    } catch (e) {
      Logger.error('[PAYMENT_SCREEN] Error parsing secured balances', e);
      balanceStr = '';
    }
    
    // If we couldn't find a balance in securedNetBalancesByDenom, use netCredexAssetsInDefaultDenom
    if (balanceStr.isEmpty) {
      Logger.data('[PAYMENT_SCREEN] Using net assets as fallback');
      try {
        final netAssets = account.balanceData.netCredexAssetsInDefaultDenom;
        Logger.data('[PAYMENT_SCREEN] Net assets string: "$netAssets"');
        
        final match = RegExp(r'([0-9,]+\.?[0-9]*)').firstMatch(netAssets);
        Logger.data('[PAYMENT_SCREEN] Net assets regex match: ${match?.group(1) ?? 'no match'}');
        
        if (match != null) {
          final numberWithCommas = match.group(1)!;
          Logger.data('[PAYMENT_SCREEN] Extracted net assets with commas: $numberWithCommas');
          balanceStr = '$numberWithCommas $denom';
        } else {
          balanceStr = '0.0 $denom';
        }
      } catch (e) {
        Logger.error('[PAYMENT_SCREEN] Error parsing net assets', e);
        balanceStr = '0.0 $denom';
      }
    }
    
    Logger.data('[PAYMENT_SCREEN] Final balance: $balanceStr');
    return balanceStr;
  }

  String _getFormattedBalance() {
    if (_selectedAccount == null) return '0.00 ${widget.invoice.currency}';
    return _getAccountBalance(_selectedAccount!);
  }

  Future<void> _processPayment() async {
    if (_selectedAccount == null) {
      setState(() {
        _errorMessage = 'Please select an account to pay from';
      });
      return;
    }

    if (!_hasSufficientBalance()) {
      _showInsufficientBalanceError();
      return;
    }

    // Validate that paymentAccountId is not null
    if (widget.invoice.paymentAccountId == null) {
      setState(() {
        _errorMessage = 'Cannot process payment: Missing payment account ID';
      });
      Logger.error('[PAYMENT_SCREEN] Payment failed: Missing payment account ID');
      return;
    }

    // Show loading dialog with Lottie animation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LoadingDialog(
        message: 'Processing payment...',
      ),
    );

    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      // Create a Credex request for the invoice payment
      final credexRequest = CredexRequest(
        issuerAccountID: _selectedAccount!.accountID,
        receiverAccountID: widget.invoice.paymentAccountId!, // Use non-null assertion since we've validated
        denomination: widget.invoice.currency,
        initialAmount: widget.invoice.totalAmount / 100, // Convert from smallest unit to decimal
        credexType: 'PURCHASE',
        offersOrRequests: 'OFFERS',
        securedCredex: true,
        invoiceID: widget.invoice.id, // Include the invoice ID in the request
      );
      
      Logger.data('[PAYMENT_SCREEN] Creating Credex payment:');
      Logger.data('[PAYMENT_SCREEN] - From account: ${_selectedAccount!.accountID}');
      Logger.data('[PAYMENT_SCREEN] - To vendor: ${widget.invoice.vendorId}');
      Logger.data('[PAYMENT_SCREEN] - Amount: ${widget.invoice.totalAmount / 100} ${widget.invoice.currency}');
      Logger.data('[PAYMENT_SCREEN] - Invoice ID: ${widget.invoice.id}');
      
      // Create the Credex transaction
      final result = await _accountRepository.createCredex(credexRequest);
      
      // Close loading dialog before showing result
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      result.fold(
        (failure) {
          setState(() {
            _isProcessingPayment = false;
            _errorMessage = failure.message ?? 'Failed to process payment';
          });
        },
        (response) async {
          // Update the invoice status to paid
          final invoiceResult = await _marketplaceRepository.updateInvoice(
            id: widget.invoice.id,
            status: InvoiceStatus.paid,
            paidAt: DateTime.now(),
          );
          
          // Log that we would ideally update the buyer ID as well
          Logger.data('[PAYMENT_SCREEN] Face-to-face transaction completed by buyer: $_memberId');
          Logger.data('[PAYMENT_SCREEN] Note: The buyerId field cannot be updated through the updateInvoice method');
          
          invoiceResult.fold(
            (failure) {
              Logger.error('Failed to update invoice status', failure);
              // Still show success since the payment went through
              _showPaymentSuccessDialog();
            },
            (updatedInvoice) {
              // Show success dialog
              _showPaymentSuccessDialog();
            },
          );
        },
      );
    } catch (e) {
      // Close loading dialog on error
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _isProcessingPayment = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
      Logger.error('Error processing payment', e);
    }
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.successGreen,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your payment has been processed successfully.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The vendor will receive your payment for ${widget.invoice.formattedTotalAmount}.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              // Close the dialog first
              Navigator.pop(context);
              
              // Navigate to home screen and remove all previous screens from the stack
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home', // Home screen route
                (route) => false, // Remove all previous routes
              );
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: _isLoading
          ? const Center(child: InlineLoadingAnimation(size: 80))
          : _buildPaymentForm(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildPaymentForm() {
    Logger.data('[PAYMENT_SCREEN] Building payment form');
    Logger.data('[PAYMENT_SCREEN] Error message: $_errorMessage');
    Logger.data('[PAYMENT_SCREEN] Accounts count: ${_accounts.length}');
    Logger.data('[PAYMENT_SCREEN] Selected account: ${_selectedAccount?.accountName ?? 'None'}');
    
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.errorRed,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.errorRed,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadAccounts,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_accounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No ${widget.invoice.currency} accounts found',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need an account with ${widget.invoice.currency} to pay this invoice.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  // Navigate to create account screen
                  Navigator.pushNamed(context, '/create-account').then((_) {
                    // Refresh accounts when returning
                    _loadAccounts();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Become a Member'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Use a Column with SingleChildScrollView instead of ListView for better visibility
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInvoiceSummary(),
          const SizedBox(height: 24),
          
          _buildAccountSelection(),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.storefront, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pay To: Vendor',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Invoice #${widget.invoice.id.substring(0, 8) }****',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                Text(
                  widget.invoice.formattedTotalAmount,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSelection() {
    Logger.data('[PAYMENT_SCREEN] Building account selection widget');
    Logger.data('[PAYMENT_SCREEN] Available accounts: ${_accounts.map((a) => a.accountName).join(', ')}');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // If no accounts, show a message instead of the dropdown
            if (_accounts.isEmpty)
              const Text(
                'No accounts available with matching currency',
                style: TextStyle(color: AppColors.errorRed),
              )
            else
              // Use a simpler dropdown for better compatibility
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textSecondary),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<DashboardAccount>(
                  value: _selectedAccount,
                  isExpanded: true,
                  underline: const SizedBox(), // Remove the default underline
                  hint: const Text('Select an account'),
                  items: _accounts.map((account) {
                    // Get the formatted balance using the same logic as _getFormattedBalance
                    final balanceStr = _getAccountBalance(account);
                    Logger.data('[PAYMENT_SCREEN] Account ${account.accountName} balance: $balanceStr');
                    
                    return DropdownMenuItem(
                      value: account,
                      // Simplified dropdown item to prevent overflow
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              account.accountName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            balanceStr,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (account) {
                    Logger.data('[PAYMENT_SCREEN] Account selected: ${account?.accountName}');
                    setState(() {
                      _selectedAccount = account;
                    });
                  },
                ),
              ),
            if (_selectedAccount != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Available: ${_getFormattedBalance()}',
                    style: TextStyle(
                      color: _hasSufficientBalance()
                          ? AppColors.textSecondary
                          : AppColors.errorRed,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (!_hasSufficientBalance()) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(
                      Icons.warning,
                      size: 16,
                      color: AppColors.errorRed,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Insufficient balance',
                      style: TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    widget.invoice.formattedTotalAmount,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text('Sign & Send'),
              onPressed: _isProcessingPayment || _isLoading ? null : _processPayment,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
