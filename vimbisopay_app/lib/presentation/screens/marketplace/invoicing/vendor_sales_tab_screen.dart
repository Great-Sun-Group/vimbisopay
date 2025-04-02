import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/models/sales_basket.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/invoice_generation_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/marketplace/basket_item_card.dart';
import 'package:vimbisopay_app/presentation/widgets/marketplace/product_selection_card.dart';

/// A screen that allows vendors to create a new sales transaction.
///
/// This screen displays the vendor's products and allows them to add
/// products to a basket for checkout.
class VendorSalesTabScreen extends StatefulWidget {
  /// Creates a new [VendorSalesTabScreen] instance.
  const VendorSalesTabScreen({
    super.key,
    String? vendorId, // Make vendorId optional since we use the current user
  });

  @override
  State<VendorSalesTabScreen> createState() => _VendorSalesTabScreenState();
}

class _VendorSalesTabScreenState extends State<VendorSalesTabScreen> with SingleTickerProviderStateMixin {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  
  bool _isLoading = true;
  String _errorMessage = '';
  List<Product> _products = [];
  SalesBasket? _basket;
  
  late  TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Track the current tab index
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with index 0 (Products tab) to default to browse mode
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    // Add listener to track tab changes
    _tabController.addListener(_handleTabChange);
    _loadVendorData();
  }

  @override
  void dispose() {
    // Remove the listener when disposing
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  // Handle tab changes
  void _handleTabChange() {
    if (_tabController.indexIsChanging || _tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  Future<void> _loadVendorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get current user
      final currentUser = await ServiceLocator.databaseHelper.getUser();
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user data';
        });
        return;
      }

      // Create a vendor object from the current user
      final vendor = Vendor(
        id: currentUser.memberId,
        memberId: currentUser.memberId,
        businessName: currentUser.dashboard?.member.firstname ?? 'My Business',
        description: 'Vendor account',
        email: '',
        phone: currentUser.phone,
        rating: 0,
        ratingCount: 0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      List<Product> allProducts = [];
      
      // Load internal accounts of type PHYSICAL_ASSET from user's dashboard
      if (currentUser.dashboard != null) {
        final dashboard = currentUser.dashboard!;
        final physicalAsssetAccounts = dashboard.accountsInternal
            .where((account) => account.accountType == 'PHYSICAL_ASSET')
            .toList();
        
        Logger.data('[VENDOR_SALES] Found ${physicalAsssetAccounts.length} PHYSICAL_ASSET accounts');
        
        // Convert internal accounts to Product objects
        final internalProducts = physicalAsssetAccounts.map((account) {
          // Create image URLs list with profile picture thumbnail if available
          List<String> imageUrls = [];
          if (account.profilePictureThumbnail != null && account.profilePictureThumbnail!.isNotEmpty) {
            Logger.data('[VENDOR_SALES] Adding profile picture thumbnail to product: ${account.profilePictureThumbnail}');
            imageUrls.add(account.profilePictureThumbnail!);
          } else {
            Logger.data('[VENDOR_SALES] No profile picture thumbnail available for account: ${account.accountID}');
          }
          
          // Create a Product from the internal account
          return Product(
            id: account.accountID,
            vendorId: vendor.id,
            name: account.accountName,
            description: 'Internal physical asset account',
            price: 0, // Default price, would need to be updated from account balance
            currency: 'USD', // Default currency
            imageUrls: imageUrls, // Include profile picture thumbnail if available
            isAvailable: true,
            accountId: account.accountID,
            createdAt: DateTime.now(), // We don't have creation date
            updatedAt: DateTime.now(), // We don't have update date
          );
        }).toList();
        
        // Add internal products to the list
        allProducts.addAll(internalProducts);
      }
      
      setState(() {
        _isLoading = false;
        _products = allProducts;
        _basket = SalesBasket(vendor: vendor);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  void _addToBasket(Product product) {
    setState(() {
      _basket!.addProduct(product);
    });
  }

  void _removeFromBasket(String productId) {
    setState(() {
      _basket!.removeProduct(productId);
    });
  }

  void _updateQuantity(String productId, int quantity) {
    setState(() {
      _basket!.updateQuantity(productId, quantity);
    });
  }

  void _clearBasket() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Basket'),
        content: const Text('Are you sure you want to clear the basket?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _basket!.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _proceedToInvoice() {
    if (_basket!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to the basket'),
        ),
      );
      return;
    }
    
    // Check if all items have a positive amount
    if (!_allItemsHavePositiveAmount()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All items must have a positive amount'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceGenerationScreen(
          basket: _basket!,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Invoice was generated successfully, clear the basket
        setState(() {
          _basket!.clear();
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice generated successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    });
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return _products;
    }
    
    final query = _searchQuery.toLowerCase();
    return _products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Check if basket has items
    final bool hasItems = _basket != null && _basket!.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Basket'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildTabView(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
  
  /// Formats a price string to ensure it has exactly 2 decimal places.
  /// 
  /// Takes a formatted price string like "$12.5" and returns "$12.50".
  /// Also handles prices like "$12" and returns "$12.00".
  String _formatPriceWithTwoDecimals(String formattedPrice) {
    // Extract the currency symbol and numeric value
    RegExp regex = RegExp(r'([^\d.]+)?([\d.]+)');
    Match? match = regex.firstMatch(formattedPrice);
    
    if (match != null) {
      String symbol = match.group(1) ?? '';
      String numericPart = match.group(2) ?? '0';
      
      // Parse the numeric part and format to 2 decimal places
      double value = double.tryParse(numericPart) ?? 0.0;
      return '$symbol${value.toStringAsFixed(2)}';
    }
    
    // Fallback if regex doesn't match
    return formattedPrice;
  }

  /// Checks if all items in the basket have a positive amount set.
  bool _allItemsHavePositiveAmount() {
    if (_basket == null || _basket!.isEmpty) return false;
    return _basket!.items.every((item) => item.amount > 0);
  }
  
  Widget _buildFloatingActionButton() {
    // Check if keyboard is visible
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    // If keyboard is visible, return an empty container (hide the FAB)
    if (isKeyboardVisible) {
      return Container();
    }
    
    // Early return if basket is null or empty
    if (_basket == null || _basket!.isEmpty) {
      return FloatingActionButton.extended(
        onPressed: null, // Disabled when basket is empty
        icon: const Icon(Icons.receipt_long),
        label: const Text('Generate Invoice'),
        backgroundColor: Colors.grey, // Use a muted color for disabled state
      );
    }
    
    // Check if all items have a positive amount
    final bool allItemsValid = _allItemsHavePositiveAmount();
    
    return FloatingActionButton.extended(
      onPressed: allItemsValid ? _proceedToInvoice : null, // Disable if any item has zero amount
      icon: const Icon(Icons.receipt_long),
      label: Row(
        children: [
          // Format the price to ensure 2 decimal places
          Text(_formatPriceWithTwoDecimals(_basket!.formattedTotalPrice)),
          const SizedBox(width: 8),
          const Text('Generate Invoice'),
        ],
      ),
      backgroundColor: allItemsValid ? AppColors.primary : Colors.grey, // Gray out if any item has zero amount
      elevation: allItemsValid ? 4 : 2, // Reduce elevation for disabled state
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
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadVendorData,
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

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildProductsTab(),
        _buildBasketTab(),
      ],
    );
  }

  Widget _buildProductsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: _filteredProducts.isEmpty
              ? _buildEmptyProductsView()
              : _buildProductsGrid(),
        ),
      ],
    );
  }

  Widget _buildEmptyProductsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No products found matching "${_searchQuery}"'
                  : 'No products available',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Clear Search'),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.6,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final isInBasket = _basket!.items.any((item) => item.product.id == product.id);
        
        return ProductSelectionCard(
          product: product,
          isInBasket: isInBasket,
          onAddToBasket: product.isAvailable
              ? () => _addToBasket(product)
              : null,
        );
      },
    );
  }

  Widget _buildBasketTab() {
    if (_basket!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shopping_basket_outlined,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your basket is empty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add products from the Products tab',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Browse Products'),
                onPressed: () {
                  _tabController.animateTo(0);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Products: ${_basket!.itemCount}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear Basket'),
                onPressed: _clearBasket,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _basket!.items.length,
            itemBuilder: (context, index) {
              final item = _basket!.items[index];
              return BasketItemCard(
                item: item,
                onQuantityChanged: (quantity) {
                  setState(() {
                    // The BasketItemCard already updates the item's quantity
                    // We just need to trigger a rebuild
                  });
                },
                onRemove: () => _removeFromBasket(item.product.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    // Early return with an empty container if basket is null or empty
    if (_basket == null || _basket!.isEmpty) {
      return Container(height: 0);
    }
    
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
                    _formatPriceWithTwoDecimals(_basket!.formattedTotalPrice),
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
              icon: const Icon(Icons.receipt_long),
              label: const Text('Generate Invoice'),
              onPressed: _proceedToInvoice,
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
