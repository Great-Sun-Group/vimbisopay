import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:provider/provider.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';

/// A screen that allows buyers to pay for invoices.
///
/// This screen is shown after a buyer views an invoice and decides to pay.
/// It allows the buyer to select a Credex account and pay for the invoice.
class PaymentScreen extends StatefulWidget {
  /// The invoice to pay.
  final Invoice invoice;

  /// The vendor who created the invoice.
  final Vendor vendor;

  /// Whether to show debug options for testing.
  final bool showDebugOptions;

  /// Creates a new [PaymentScreen] instance.
  const PaymentScreen({
    super.key,
    required this.invoice,
    required this.vendor,
    this.showDebugOptions = true, // Enable by default for development
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
  final _noteController = TextEditingController();
  String? _memberId;
  bool _useDebugAccounts = false;

  @override
  void initState() {
    super.initState();
    Logger.data('[PAYMENT_SCREEN] Initializing payment screen');
    _loadAccounts();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    Logger.data('[PAYMENT_SCREEN] Loading accounts');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // If debug mode is enabled and user chooses to use debug accounts
    if (widget.showDebugOptions && _useDebugAccounts) {
      Logger.data('[PAYMENT_SCREEN] Using debug accounts');
      _loadDebugAccounts();
      return;
    }

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

  void _loadDebugAccounts() {
    Logger.data('[PAYMENT_SCREEN] Loading debug accounts');
    
    // Create mock accounts for testing
    final mockAccounts = [
      DashboardAccount(
        accountID: 'debug-account-1',
        accountName: 'Debug Account 1',
        accountHandle: 'debug1',
        defaultDenom: widget.invoice.currency,
        isOwnedAccount: true,
        balanceData: BalanceData(
          securedNetBalancesByDenom: ['1000.00 ${widget.invoice.currency}'],
          unsecuredBalances: UnsecuredBalances(
            totalPayables: '0.00 ${widget.invoice.currency}',
            totalReceivables: '0.00 ${widget.invoice.currency}',
            netPayRec: '0.00 ${widget.invoice.currency}',
          ),
          netCredexAssetsInDefaultDenom: '1000.00 ${widget.invoice.currency}',
        ),
        pendingInData: PendingData(
          success: true,
          data: [],
          message: 'No pending offers',
        ),
        pendingOutData: PendingData(
          success: true,
          data: [],
          message: 'No pending outgoing offers',
        ),
        sendOffersTo: SendOffersTo(
          memberID: 'debug-member',
          firstname: 'Debug',
          lastname: 'User',
        ),
      ),
      DashboardAccount(
        accountID: 'debug-account-2',
        accountName: 'Debug Account 2 (Low Balance)',
        accountHandle: 'debug2',
        defaultDenom: widget.invoice.currency,
        isOwnedAccount: true,
        balanceData: BalanceData(
          securedNetBalancesByDenom: ['10.00 ${widget.invoice.currency}'],
          unsecuredBalances: UnsecuredBalances(
            totalPayables: '0.00 ${widget.invoice.currency}',
            totalReceivables: '0.00 ${widget.invoice.currency}',
            netPayRec: '0.00 ${widget.invoice.currency}',
          ),
          netCredexAssetsInDefaultDenom: '10.00 ${widget.invoice.currency}',
        ),
        pendingInData: PendingData(
          success: true,
          data: [],
          message: 'No pending offers',
        ),
        pendingOutData: PendingData(
          success: true,
          data: [],
          message: 'No pending outgoing offers',
        ),
        sendOffersTo: SendOffersTo(
          memberID: 'debug-member',
          firstname: 'Debug',
          lastname: 'User',
        ),
      ),
    ];
    
    _memberId = 'debug-member';
    
    setState(() {
      _isLoading = false;
      _accounts = mockAccounts;
      _selectedAccount = mockAccounts.first;
    });
    
    Logger.data('[PAYMENT_SCREEN] Loaded ${mockAccounts.length} debug accounts');
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
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to add funds screen
              Navigator.pushNamed(context, '/add-funds').then((_) {
                // Refresh accounts when returning from add funds
                _loadAccounts();
              });
            },
            child: const Text('Add Funds'),
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

    setState(() {
      _isProcessingPayment = true;
      _errorMessage = null;
    });

    try {
      // Create a Credex request for the invoice payment
      final credexRequest = CredexRequest(
        issuerAccountID: _selectedAccount!.accountID,
        receiverAccountID: widget.vendor.memberId, // Vendor's member ID
        denomination: widget.invoice.currency,
        initialAmount: widget.invoice.totalAmount / 100, // Convert from smallest unit to decimal
        credexType: 'PURCHASE',
        offersOrRequests: 'OFFERS',
        securedCredex: true,
      );
      
      Logger.data('[PAYMENT_SCREEN] Creating Credex payment:');
      Logger.data('[PAYMENT_SCREEN] - From account: ${_selectedAccount!.accountID}');
      Logger.data('[PAYMENT_SCREEN] - To vendor: ${widget.vendor.memberId}');
      Logger.data('[PAYMENT_SCREEN] - Amount: ${widget.invoice.totalAmount / 100} ${widget.invoice.currency}');
      Logger.data('[PAYMENT_SCREEN] - Invoice ID: ${widget.invoice.id}');
      
      // Create the Credex transaction
      final result = await _accountRepository.createCredex(credexRequest);
      
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
            notes: _noteController.text.isNotEmpty ? _noteController.text : null,
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to invoice screen with success result
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
        title: const Text('Payment'),
      ),
      body: Column(
        children: [
          // Debug options
          if (widget.showDebugOptions) _buildDebugOptions(),
          
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildPaymentForm(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildDebugOptions() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, size: 16, color: AppColors.yellowPrimary),
              const SizedBox(width: 4),
              const Text(
                'Debug Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.yellowPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _useDebugAccounts,
                onChanged: (value) {
                  setState(() {
                    _useDebugAccounts = value;
                  });
                  _loadAccounts();
                },
                activeColor: AppColors.yellowPrimary,
              ),
            ],
          ),
          if (_useDebugAccounts)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                'Using mock accounts with ${widget.invoice.currency}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const Divider(),
        ],
      ),
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
                label: const Text('Create Account'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
              if (widget.showDebugOptions) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _useDebugAccounts = true;
                    });
                    _loadAccounts();
                  },
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Use Debug Accounts'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.yellowPrimary,
                  ),
                ),
              ],
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
          // Debug info in development mode
          if (widget.showDebugOptions) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.yellowPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.yellowPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Debug Info: ${_accounts.length} accounts available',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Selected: ${_selectedAccount?.accountName ?? 'None'}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          _buildInvoiceSummary(),
          const SizedBox(height: 24),
          
          // Account selection with visible border for debugging
          Container(
            decoration: BoxDecoration(
              border: widget.showDebugOptions 
                  ? Border.all(color: AppColors.yellowPrimary, width: 2)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildAccountSelection(),
          ),
          
          const SizedBox(height: 24),
          _buildNoteField(),
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
                  backgroundImage: widget.vendor.profileImageUrl != null
                      ? NetworkImage(widget.vendor.profileImageUrl!)
                      : null,
                  child: widget.vendor.profileImageUrl == null
                      ? const Icon(Icons.storefront, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay to: ${widget.vendor.businessName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Invoice #${widget.invoice.id.substring(0, 8)}',
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
            Row(
              children: [
                const Text(
                  'Select Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.showDebugOptions)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.yellowPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_accounts.length} accounts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.yellowPrimary,
                      ),
                    ),
                  ),
              ],
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  account.accountName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '@${account.accountHandle}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
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
                Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      size: 16,
                      color: AppColors.errorRed,
                    ),
                    const SizedBox(width: 8),
                    const Text(
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

  Widget _buildNoteField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Note (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a note to the vendor',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              maxLines: 3,
              maxLength: 100,
            ),
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
              label: const Text('Pay Now'),
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
