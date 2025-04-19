import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/constants/url_constants.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';
import 'package:vimbisopay_app/presentation/widgets/account_qr_dialog.dart';
import 'package:vimbisopay_app/presentation/widgets/account_selection_bottom_sheet.dart';
import 'package:vimbisopay_app/presentation/models/send_credex_arguments.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';

class HomeActionButtons extends StatelessWidget {
  final List<DashboardAccount>? accounts;
  final VoidCallback? onSendTap;
  final AccountRepository accountRepository;
  final HomeBloc homeBloc;
  final DatabaseHelper databaseHelper;

  const HomeActionButtons({
    super.key,
    this.accounts,
    this.onSendTap,
    required this.accountRepository,
    required this.homeBloc,
    required this.databaseHelper,
  });

  void _handleSendTap(BuildContext context) {
    if (accounts == null || accounts!.isEmpty) {
      Logger.interaction('Send tapped but no accounts available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No accounts available to offer from',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (accounts!.length == 1) {
      Logger.interaction('Navigating to send credex with single account');
      Navigator.pushNamed(
        context,
        '/send-credex',
        arguments: SendCredexArguments(
          senderAccount: accounts!.first,
          accountRepository: accountRepository,
          homeBloc: homeBloc,
          databaseHelper: databaseHelper,
        ),
      );
    } else {
      Logger.interaction('Showing account selection for send');
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.transparent,
        isScrollControlled: true,
          builder: (context) => AccountSelectionBottomSheet(
            accounts: accounts!,
            action: AccountSelectionAction.send,
            accountRepository: accountRepository,
            homeBloc: homeBloc,
            databaseHelper: databaseHelper,
          ),
      );
    }
  }

  void _handleReceiveTap(BuildContext context) {
    if (accounts == null || accounts!.isEmpty) {
      Logger.interaction('Receive tapped but no accounts available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No accounts available to receive to',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (accounts!.length == 1) {
      Logger.interaction('Showing QR for single account');
      _showQRDialog(context, accounts!.first);
    } else {
      Logger.interaction('Showing account selection for receive');
      _showAccountSelection(context);
    }
  }

  void _showQRDialog(BuildContext context, DashboardAccount account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(HomeConstants.cardBorderRadius),
          ),
        ),
        child: AccountQRDialog(account: account),
      ),
    );
  }

  void _showAccountSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
          builder: (context) => AccountSelectionBottomSheet(
            accounts: accounts!,
            action: AccountSelectionAction.receive,
            accountRepository: accountRepository,
            homeBloc: homeBloc,
            databaseHelper: databaseHelper,
          ),
    );
  }
  
  void _handleMarketplaceTap(BuildContext context) {
    Logger.interaction('Marketplace tab tapped');
    Navigator.pushNamed(context, '/marketplace');
  }
  
  void _handleQRScanTap(BuildContext context) {
    Logger.interaction('QR Scan button tapped');
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const ScanQRScreen(showDebugOptions: false),
        fullscreenDialog: true,
      ),
    ).then((result) {
      if (result != null && context.mounted) {
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
        
        // Process recipient QR code (expected format: handle#accountId)
        final parts = result.split('#');
        if (parts.length == 2) {
          // Store the scanned QR code data
          final handle = parts[0].startsWith('@') ? parts[0].substring(1) : parts[0];
          final accountId = parts[1];
          
          // Show a success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recipient found: @$handle'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.success,
            ),
          );
          
          // If we have multiple accounts, show account selection
          if (accounts != null && accounts!.length > 1) {
            Logger.interaction('Showing account selection for send after QR scan');
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.transparent,
              isScrollControlled: true,
              builder: (context) => AccountSelectionBottomSheet(
                accounts: accounts!,
                action: AccountSelectionAction.send,
                accountRepository: accountRepository,
                homeBloc: homeBloc,
                databaseHelper: databaseHelper,
              ),
            ).then((selectedAccount) {
              // After account selection, navigate to send credex screen with the recipient info
              if (selectedAccount != null && selectedAccount is DashboardAccount) {
                Logger.interaction('Navigating to send credex with selected account and recipient info');
                Navigator.pushNamed(
                  context,
                  '/send-credex',
                  arguments: SendCredexArguments(
                    senderAccount: selectedAccount,
                    accountRepository: accountRepository,
                    homeBloc: homeBloc,
                    databaseHelper: databaseHelper,
                    recipientHandle: handle,
                    recipientAccountId: accountId,
                  ),
                );
              }
            });
          } else if (accounts != null && accounts!.length == 1) {
            // If we have only one account, use it directly
            Logger.interaction('Navigating to send credex with single account and recipient info');
            Navigator.pushNamed(
              context,
              '/send-credex',
              arguments: SendCredexArguments(
                senderAccount: accounts!.first,
                accountRepository: accountRepository,
                homeBloc: homeBloc,
                databaseHelper: databaseHelper,
                recipientHandle: handle,
                recipientAccountId: accountId,
              ),
            );
          } else {
            // No accounts available
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No accounts available to offer from',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else {
          // Invalid QR code format
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid QR code format. Expected format: handle#accountId or invoice URL'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if marketplace feature is enabled
    final bool isMarketplaceEnabled = ServiceLocator.featureFlagService.isMarketplaceEnabled();
    
    // Create navigation items
    final List<BottomNavigationBarItem> items = [
      BottomNavigationBarItem(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.1),
          ),
          child: const Icon(Icons.payments_outlined),
        ),
        label: 'Offer',
      ),
      BottomNavigationBarItem(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.1),
          ),
          child: const Icon(Icons.account_balance_wallet_outlined),
        ),
        label: 'Receive',
      ),
      // Add QR scan button
      BottomNavigationBarItem(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.1),
          ),
          child: const Icon(Icons.qr_code_scanner),
        ),
        label: 'Scan',
      ),
    ];
    
    // Add marketplace tab if feature is enabled
    if (isMarketplaceEnabled) {
      items.add(
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: const Icon(Icons.storefront_outlined),
          ),
          label: 'Market',
        ),
      );
    }
    
    return BottomNavigationBar(
      backgroundColor: AppColors.surface,
      elevation: 8,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.primary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: items,
      onTap: (index) {
        if (index == 0) {
          _handleSendTap(context);
        } else if (index == 1) {
          _handleReceiveTap(context);
        } else if (index == 2) {
          _handleQRScanTap(context);
        } else if (isMarketplaceEnabled && index == 3) {
          _handleMarketplaceTap(context);
        }
      },
    );
  }
}
