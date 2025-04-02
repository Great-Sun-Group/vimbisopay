import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

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
              final testMemberId = 'test_member_id';
              final testVendorId = 'v_test';
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
}
