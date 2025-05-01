import 'package:flutter/material.dart';
import 'package:vimbisopay_app/infrastructure/services/storage/storage_service.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';

/// A helper class for handling first-time visit to the marketplace.
class MarketplaceFirstVisitHelper {
  final BuildContext _context;
  final VoidCallback _onBecomeVendor;

  MarketplaceFirstVisitHelper(this._context, this._onBecomeVendor);

  /// Checks if this is the user's first visit to the marketplace.
  ///
  /// If it is, shows a welcome dialog.
  Future<void> checkFirstTimeVisit() async {
    try {
      final storage = ServiceLocator.storageService;
      final isFirstVisit = !(await storage.containsKey('has_visited_marketplace'));
      
      if (isFirstVisit) {
        // Mark as visited
        await storage.setBool('has_visited_marketplace', true);
        
        // Show first-time prompt after the screen is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showFirstTimeMarketplaceDialog();
        });
      }
    } catch (e) {
      Logger.error('Error checking first-time visit', e);
    }
  }
  
  /// Shows a welcome dialog for first-time visitors.
  void _showFirstTimeMarketplaceDialog() {
    showDialog(
      context: _context,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to Vimbiso Marketplace!'),
        content: const Text(
          'Would you like to sell your products and services in the marketplace?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _onBecomeVendor();
            },
            child: const Text('Become a Vendor'),
          ),
        ],
      ),
    );
  }
}
