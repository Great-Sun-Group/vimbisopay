import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// A helper class for handling vendor actions in the marketplace.
class MarketplaceVendorActions {
  final BuildContext _context;
  final VoidCallback _onNewSale;
  final VoidCallback _onManageInventory;
  final VoidCallback _onStoreInformation;

  MarketplaceVendorActions(
    this._context, {
    required VoidCallback onNewSale,
    required VoidCallback onManageInventory,
    required VoidCallback onStoreInformation,
  })  : _onNewSale = onNewSale,
        _onManageInventory = onManageInventory,
        _onStoreInformation = onStoreInformation;

  /// Shows a bottom sheet with vendor action options.
  void showVendorActionSheet() {
    showModalBottomSheet(
      context: _context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.point_of_sale, color: AppColors.primary),
            title: const Text('New Sale'),
            onTap: () {
              Navigator.pop(context);
              _onNewSale();
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2, color: AppColors.primary),
            title: const Text('Manage Inventory'),
            onTap: () {
              Navigator.pop(context);
              _onManageInventory();
            },
          ),
          ListTile(
            leading: const Icon(Icons.store, color: AppColors.primary),
            title: const Text('Store Information'),
            onTap: () {
              Navigator.pop(context);
              _onStoreInformation();
            },
          ),
        ],
      ),
    );
  }
}
