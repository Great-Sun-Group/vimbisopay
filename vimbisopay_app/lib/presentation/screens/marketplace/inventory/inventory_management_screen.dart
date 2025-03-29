import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/add_edit_sku_screen.dart';

/// A screen for managing inventory for a vendor.
///
/// This screen displays a list of SKUs (internal accounts) for a vendor
/// and allows them to add, edit, and manage inventory for each SKU.
class InventoryManagementScreen extends StatefulWidget {
  /// The ID of the vendor whose inventory is being managed.
  final String vendorId;

  /// Creates a new [InventoryManagementScreen] instance.
  const InventoryManagementScreen({
    super.key,
    required this.vendorId,
  });

  @override
  State<InventoryManagementScreen> createState() => _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _skus = []; // This would be a list of internal accounts in the real implementation
  
  @override
  void initState() {
    super.initState();
    _loadSkus();
  }
  
  Future<void> _loadSkus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get current user from the database
      final currentUser = await ServiceLocator.databaseHelper.getUser();
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user data';
          _skus = [];
        });
        return;
      }

      // Check if user has a dashboard with internal accounts
      if (currentUser.dashboard == null || currentUser.dashboard!.accountsInternal.isEmpty) {
        setState(() {
          _isLoading = false;
          _skus = [];
        });
        return;
      }

      // Filter for PHYSICAL_ASSET accounts
      final physicalAssetAccounts = currentUser.dashboard!.accountsInternal
          .where((account) => account.accountType == 'PHYSICAL_ASSET')
          .toList();
      
      Logger.data('[INVENTORY_MANAGEMENT] Found ${physicalAssetAccounts.length} PHYSICAL_ASSET accounts');
      
      // Map internal accounts to products format for UI
      final mappedSkus = physicalAssetAccounts.map((account) {
        // Create image URLs list with profile picture thumbnail if available
        List<String> imageUrls = [];
        if (account.profilePictureThumbnail != null && account.profilePictureThumbnail!.isNotEmpty) {
          imageUrls.add(account.profilePictureThumbnail!);
        }
        
        // Create a product from the internal account
        return {
          'id': account.accountID,
          'name': account.accountName,
          'description': 'Internal physical asset account',
          'price': 0, // Default price
          'currency': 'CXX', // Default currency
          'category': 'Internal',
          'accountId': account.accountID,
          'isAvailable': true,
        };
      }).toList();
      
      setState(() {
        _skus = mappedSkus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load SKUs: $e';
      });
    }
  }
  
  Future<void> _navigateToAddSku() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSkuScreen(
          vendorId: widget.vendorId,
        ),
      ),
    );
    
    if (result != null && result is Map && result['success'] == true) {
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'SKU added successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
      
      // Check if the result contains a product
      if (result.containsKey('product') && result['product'] != null) {
        final productMap = result['product'] as Map<String, dynamic>;
        Logger.data('[INVENTORY_MANAGEMENT] Retrieved product data from AddEditSkuScreen');
        
        try {
          // Create a new product map from the data
          final retrievedProduct = {
            'id': productMap['id'],
            'name': productMap['name'],
            'description': productMap['description'],
            'price': productMap['price'],
            'currency': productMap['currency'],
            'category': productMap['category'],
            'accountId': productMap['accountId'],
            'isAvailable': productMap['isAvailable'],
          };
          
          // Update the state with the new product
          setState(() {
            // Add the new product to the list
            _skus.add(retrievedProduct);
          });
          
          // No need to reload all SKUs
          return;
        } catch (e) {
          Logger.error('[INVENTORY_MANAGEMENT] Error creating product map from result data', e);
          // Continue to reload all SKUs
        }
      }
      
      // Refresh the SKU list
      _loadSkus();
    }
  }
  
  Future<void> _navigateToEditSku(String skuId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditSkuScreen(
          vendorId: widget.vendorId,
          skuId: skuId,
        ),
      ),
    );
    
    if (result != null && result is Map && result['success'] == true) {
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'SKU updated successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
      
      // Check if the result contains a product
      if (result.containsKey('product') && result['product'] != null) {
        final productMap = result['product'] as Map<String, dynamic>;
        Logger.data('[INVENTORY_MANAGEMENT] Retrieved product data from AddEditSkuScreen');
        
        try {
          // Create a new product map from the data
          final retrievedProduct = {
            'id': productMap['id'],
            'name': productMap['name'],
            'description': productMap['description'],
            'price': productMap['price'],
            'currency': productMap['currency'],
            'category': productMap['category'],
            'accountId': productMap['accountId'],
            'isAvailable': productMap['isAvailable'],
          };
          
          // Update the state with the updated product
          setState(() {
            // Find the index of the product with the matching ID
            final index = _skus.indexWhere((sku) => sku['id'] == skuId);
            if (index != -1) {
              // Replace the product at that index
              _skus[index] = retrievedProduct;
            } else {
              // If not found, add it to the list
              _skus.add(retrievedProduct);
            }
          });
          
          // No need to reload all SKUs
          return;
        } catch (e) {
          Logger.error('[INVENTORY_MANAGEMENT] Error creating product map from result data', e);
          // Continue to reload all SKUs
        }
      }
      
      // Refresh the SKU list
      _loadSkus();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildSkuList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddSku,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildErrorView() {
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
              onPressed: _loadSkus,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSkuList() {
    if (_skus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No SKUs found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first SKU to start managing inventory',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _navigateToAddSku,
              icon: const Icon(Icons.add),
              label: const Text('Add SKU'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _skus.length,
      itemBuilder: (context, index) {
        final sku = _skus[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(
                  sku['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(sku['description']),
                trailing: sku['isAvailable']
                    ? const Icon(Icons.check_circle, color: AppColors.successGreen)
                    : const Icon(Icons.cancel, color: AppColors.errorRed),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Price',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            _formatPrice(sku['price'], sku['currency']),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            sku['category'],
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            sku['accountId'] != null 
                                ? sku['accountId'].toString().substring(0, 8) + '...'
                                : 'Not assigned',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: sku['accountId'] != null
                                  ? AppColors.successGreen
                                  : AppColors.errorRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ButtonBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () => _navigateToEditSku(sku['id']),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  String _formatPrice(int price, String currency) {
    // Simple formatting for common currencies
    String symbol = '';
    switch (currency) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
      default:
        return '$currency ${price / 100}';
    }
    return '$symbol${price / 100}';
  }
}
