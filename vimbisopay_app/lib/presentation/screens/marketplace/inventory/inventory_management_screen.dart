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
      // Fetch products from the repository
      final result = await _marketplaceRepository.getProductsByVendor(widget.vendorId);
      
      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load SKUs';
            _skus = [];
          });
        },
        (products) {
          setState(() {
            // Convert products to a format that can be used by the UI
            _skus = products.map((product) => {
              'id': product.id,
              'name': product.name,
              'description': product.description,
              'price': product.price,
              'currency': product.currency,
              'category': product.category,
              'inventory': product.inventory ?? 0,
              'isAvailable': product.isAvailable,
            }).toList();
            _isLoading = false;
          });
        },
      );
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
    
    if (result == true) {
      // Refresh the SKU list if a new SKU was added
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
    
    if (result == true) {
      // Refresh the SKU list if a SKU was edited
      _loadSkus();
    }
  }
  
  Future<void> _showAdjustInventoryDialog(dynamic sku) async {
    final TextEditingController quantityController = TextEditingController();
    String? errorMessage;
    bool isAdding = true;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Adjust Inventory for ${sku['name']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Inventory: ${sku['inventory']}'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Add'),
                            icon: Icon(Icons.add),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Remove'),
                            icon: Icon(Icons.remove),
                          ),
                        ],
                        selected: {isAdding},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            isAdding = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'Enter quantity to adjust',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  // Validate input
                  final quantityText = quantityController.text.trim();
                  if (quantityText.isEmpty) {
                    setState(() {
                      errorMessage = 'Please enter a quantity';
                    });
                    return;
                  }
                  
                  int? quantity;
                  try {
                    quantity = int.parse(quantityText);
                    if (quantity <= 0) {
                      setState(() {
                        errorMessage = 'Quantity must be greater than zero';
                      });
                      return;
                    }
                  } catch (e) {
                    setState(() {
                      errorMessage = 'Please enter a valid number';
                    });
                    return;
                  }
                  
                  // Check if removing more than available
                  if (!isAdding && quantity > sku['inventory']) {
                    setState(() {
                      errorMessage = 'Cannot remove more than available inventory';
                    });
                    return;
                  }
                  
                  // Call the repository to update the product's inventory
                  _updateProductInventory(
                    sku['id'],
                    isAdding ? sku['inventory'] + quantity : sku['inventory'] - quantity,
                  ).then((success) {
                    if (success) {
                      Navigator.pop(context, {
                        'isAdding': isAdding,
                        'quantity': quantity,
                      });
                    } else {
                      setState(() {
                        errorMessage = 'Failed to update inventory';
                      });
                    }
                  });
                },
                child: const Text('Adjust'),
              ),
            ],
          );
        },
      ),
    ).then((result) {
      if (result != null) {
        // Update the local state
        setState(() {
          if (result['isAdding']) {
            sku['inventory'] += result['quantity'];
          } else {
            sku['inventory'] -= result['quantity'];
          }
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['isAdding']
                  ? 'Added ${result['quantity']} to inventory'
                  : 'Removed ${result['quantity']} from inventory',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
  
  Future<void> _showInventoryHistoryDialog(dynamic sku) async {
    // In a real implementation, this would fetch the inventory history from the repository
    // For now, we'll just show a dialog with simulated data
    
    // Simulate inventory history data
    final List<Map<String, dynamic>> history = [
      {
        'id': 'txn-1',
        'type': 'add',
        'quantity': 10,
        'date': DateTime.now().subtract(const Duration(days: 7)),
        'notes': 'Initial inventory',
      },
      {
        'id': 'txn-2',
        'type': 'add',
        'quantity': 20,
        'date': DateTime.now().subtract(const Duration(days: 3)),
        'notes': 'Restocked',
      },
      {
        'id': 'txn-3',
        'type': 'remove',
        'quantity': 5,
        'date': DateTime.now().subtract(const Duration(days: 1)),
        'notes': 'Sold to customer',
      },
    ];
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Inventory History for ${sku['name']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final transaction = history[index];
                    final isAdd = transaction['type'] == 'add';
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isAdd ? Colors.green : Colors.red,
                        child: Icon(
                          isAdd ? Icons.add : Icons.remove,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        isAdd
                            ? 'Added ${transaction['quantity']} units'
                            : 'Removed ${transaction['quantity']} units',
                      ),
                      subtitle: Text(
                        '${transaction['date'].toString().substring(0, 16)} - ${transaction['notes']}',
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
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
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.cancel, color: Colors.red),
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
                            'Inventory',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${sku['inventory']} units',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: sku['inventory'] > 0
                                  ? Colors.green
                                  : Colors.red,
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
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                    onPressed: () => _showInventoryHistoryDialog(sku),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () => _navigateToEditSku(sku['id']),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.inventory),
                    label: const Text('Adjust'),
                    onPressed: () => _showAdjustInventoryDialog(sku),
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
  
  /// Updates a product's inventory in the repository.
  ///
  /// Returns true if the update was successful, false otherwise.
  Future<bool> _updateProductInventory(String productId, int newInventory) async {
    try {
      // Call the repository to update the product's inventory
      final result = await _marketplaceRepository.updateProduct(
        id: productId,
        inventory: newInventory,
      );
      
      return result.fold(
        (failure) {
          Logger.error('Failed to update product inventory', failure);
          return false;
        },
        (product) => true,
      );
    } catch (e) {
      Logger.error('Error updating product inventory', e);
      return false;
    }
  }
}
