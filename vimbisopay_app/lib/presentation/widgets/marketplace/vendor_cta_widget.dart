import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';

/// A widget that displays vendor call-to-action content in the marketplace.
class VendorCTAWidget extends StatelessWidget {
  final bool isVendor;
  final bool showBrowseMode;
  final Function(Set<bool>) onModeChanged;
  final VoidCallback onBecomeVendor;
  final Future<User?> Function() getUserFunction;
  final bool Function(User?) canBecomeVendorFunction;
  final bool isCheckingVendorStatus;

  const VendorCTAWidget({
    super.key,
    required this.isVendor,
    required this.showBrowseMode,
    required this.onModeChanged,
    required this.onBecomeVendor,
    required this.getUserFunction,
    required this.canBecomeVendorFunction,
    this.isCheckingVendorStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCheckingVendorStatus) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (isVendor) {
      return _buildVendorModeToggle(context);
    } else {
      return _buildNonVendorCTA(context);
    }
  }

  /// Builds the mode toggle UI for vendors.
  Widget _buildVendorModeToggle(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Marketplace Mode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showBrowseMode 
                  ? 'Browse and discover products from other vendors in the marketplace.'
                  : 'Manage your store and view your own products.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Browse'),
                    icon: Icon(Icons.search),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('My Store'),
                    icon: Icon(Icons.storefront),
                  ),
                ],
                selected: {showBrowseMode},
                onSelectionChanged: onModeChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the CTA UI for non-vendors.
  Widget _buildNonVendorCTA(BuildContext context) {
    // Always get the latest user data from the database
    // This ensures we have the most up-to-date activateMarket status
    Logger.data('[MARKETPLACE] Getting latest user data from database for vendor CTA');
    return FutureBuilder<User?>(
      future: getUserFunction(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final user = snapshot.data;
        final canBecomeVendor = canBecomeVendorFunction(user);
        
        Logger.data('[MARKETPLACE] User activateMarket status: ${user?.activateMarket}');
        Logger.data('[MARKETPLACE] Can become vendor: $canBecomeVendor');
        
        return _buildVendorCTAContent(context, canBecomeVendor);
      },
    );
  }
  
  /// Builds the appropriate CTA content based on whether the user can become a vendor.
  Widget _buildVendorCTAContent(BuildContext context, bool canBecomeVendor) {
    if (!canBecomeVendor) {
      // If the user can't become a vendor, show a message
      return Card(
        margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Marketplace',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse products and services from vendors in the marketplace.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show CTA for non-vendors who can become vendors
    return Card(
      margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sell in the Marketplace',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a vendor profile to sell your products and services.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Logger.data('Become a Vendor button tapped');
                  onBecomeVendor();
                },
                icon: const Icon(Icons.storefront),
                label: const Text('Become a Vendor'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
