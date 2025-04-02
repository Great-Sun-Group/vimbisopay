import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/inventory_management_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/store_information_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/vendor_profile_screen.dart';

/// A helper class for handling navigation within the marketplace.
class MarketplaceNavigation {
  final BuildContext _context;

  MarketplaceNavigation(this._context);

  /// Navigates to the vendor registration screen.
  ///
  /// If the user is not logged in, shows a snackbar message.
  void navigateToVendorRegistration({
    required String? memberId,
    required dynamic user,
    required Function() onReturn,
  }) {
    if (user == null) {
      // Show login prompt if user is not logged in
      ScaffoldMessenger.of(_context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to become a vendor'),
          backgroundColor: AppColors.errorRed,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Navigate to vendor registration with user data
    Navigator.pushNamed(
      _context,
      '/vendor-registration',
      arguments: {
        'memberId': memberId,
        'user': user, // Pass the entire user object to pre-populate fields
      },
    ).then((_) {
      // Callback when returning from registration
      onReturn();
    });
  }

  /// Navigates to the vendor profile screen.
  ///
  /// If [replace] is true, replaces the current route to prevent back navigation.
  void navigateToVendorProfile({
    required String vendorId,
    bool replace = false,
    bool isOwner = true,
  }) {
    if (replace) {
      // Replace current route to prevent back navigation to marketplace
      Navigator.pushReplacement(
        _context,
        MaterialPageRoute(
          builder: (context) => VendorProfileScreen(
            vendorId: vendorId,
            isOwner: isOwner,
          ),
        ),
      );
    } else {
      // Regular push for normal navigation
      Navigator.pushNamed(
        _context,
        '/vendor-profile',
        arguments: {
          'vendorId': vendorId,
          'isOwner': isOwner,
        },
      );
    }
  }
  
  /// Navigates to the store information screen.
  void navigateToStoreInformation({
    required String storeId,
    bool isOwner = true,
  }) {
    Logger.data('[MARKETPLACE] Navigating to store information with ID: $storeId');
    
    Navigator.push(
      _context,
      MaterialPageRoute(
        builder: (context) => StoreInformationScreen(
          storeId: storeId,
          isOwner: isOwner,
        ),
      ),
    );
  }

  /// Navigates to the inventory management screen.
  void navigateToInventoryManagement({
    required String vendorId,
  }) {
    Navigator.push(
      _context,
      MaterialPageRoute(
        builder: (context) => InventoryManagementScreen(
          vendorId: vendorId,
        ),
      ),
    );
  }

  /// Navigates to the new sale screen.
  void navigateToNewSale() {
    // No need to check for vendorId or pass it as an argument
    // since VendorSalesTabScreen now uses the current user
    Navigator.pushNamed(
      _context,
      '/vendor-sales-tab',
    );
  }

  /// Navigates to the search results screen.
  void navigateToSearchResults({
    required String query,
    String? vendorId,
    bool filterOwnProducts = false,
  }) {
    Navigator.pushNamed(
      _context,
      '/search-results',
      arguments: {
        'query': query,
        'vendorId': vendorId,
        'filterOwnProducts': filterOwnProducts,
      },
    );
  }
}
