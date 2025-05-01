import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';

/// A helper class for debugging marketplace functionality.
class MarketplaceDebugHelper {
  final BuildContext _context;
  final Function(String?, bool, String?) _onDebugValuesSet;

  MarketplaceDebugHelper(this._context, this._onDebugValuesSet);

  /// Shows a dialog with debug information and actions.
  void showDebugInfo({
    required String? memberId,
    required bool isVendor,
    required String? vendorId,
  }) {
    showDialog(
      context: _context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'User Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Member ID: ${memberId ?? 'null'}'),
              const SizedBox(height: 8),
              
              const Text(
                'Vendor Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Is Vendor: $isVendor'),
              Text('Vendor ID: ${vendorId ?? 'null'}'),
              const SizedBox(height: 8),
              
              const Text(
                'Feature Flags:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Marketplace Enabled: ${ServiceLocator.featureFlagService.isMarketplaceEnabled()}'),
              const SizedBox(height: 8),
              
              const Text(
                'Debug Actions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Set test values for debugging
              const testMemberId = 'test_member_id';
              const testVendorId = 'v_test';
              _onDebugValuesSet(testMemberId, true, testVendorId);
              
              Logger.data('DEBUG MODE: Set test vendor values - memberId: $testMemberId, isVendor: true, vendorId: $testVendorId');
              ScaffoldMessenger.of(_context).showSnackBar(
                const SnackBar(
                  content: Text('Test vendor values set'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Set Test Vendor'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              // Reset debug values
              _onDebugValuesSet(null, false, null);
              
              Logger.data('DEBUG MODE: Reset debug values');
              ScaffoldMessenger.of(_context).showSnackBar(
                const SnackBar(
                  content: Text('Debug values reset'),
                  backgroundColor: AppColors.yellowPrimary,
                ),
              );
            },
            child: const Text('Reset Debug Values'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog with user account information.
  static Future<void> showAccountInfo(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LoadingDialog(
          message: 'Loading account information...',
        ),
      );
      
      // Get user data
      final user = await ServiceLocator.databaseHelper.getUser();
      
      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        
        // Build account information
        final internalAccounts = user.dashboard?.accountsInternal ?? [];
        final regularAccounts = user.dashboard?.accounts ?? [];
        
        final internalAccountsText = internalAccounts.isEmpty
            ? 'No internal accounts found'
            : internalAccounts.map((a) => 
                '${a.accountName}: ${a.accountType} (${a.accountID})'
              ).join('\n');
        
        final regularAccountsText = regularAccounts.isEmpty
            ? 'No regular accounts found'
            : regularAccounts.map((a) => 
                '${a.accountName}: ${a.accountType} (${a.accountID})'
              ).join('\n');
        
        // Show dialog with account information
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Account Information'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'User Information:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Member ID: ${user.memberId}'),
                    Text('Phone: ${user.phone}'),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Internal Accounts:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SelectableText(internalAccountsText),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Regular Accounts:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SelectableText(regularAccountsText),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Error showing account information', e);
      
      // Dismiss loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
