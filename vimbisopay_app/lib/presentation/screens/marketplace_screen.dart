import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/inventory_management_screen.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';

/// Marketplace screen for the VimbisoPay app.
///
/// This screen is only accessible when the marketplace feature flag is enabled.
/// It provides access to the marketplace functionality including vendor profiles,
/// product listings, and invoicing.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  bool _isLoading = true;
  String _errorMessage = '';
  List<Product> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isVendor = false;
  bool _isCheckingVendorStatus = false;
  String? _memberId;
  String? _vendorId;

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('MarketplaceScreen initialized');
    _loadProducts();
    _checkVendorStatus();
    _checkFirstTimeVisit();
  }
  
  Future<void> _checkFirstTimeVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstVisit = !prefs.containsKey('has_visited_marketplace');
      
      if (isFirstVisit) {
        // Mark as visited
        await prefs.setBool('has_visited_marketplace', true);
        
        // Show first-time prompt after the screen is built
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFirstTimeMarketplaceDialog();
          });
        }
      }
    } catch (e) {
      Logger.error('Error checking first-time visit', e);
    }
  }
  
  void _showFirstTimeMarketplaceDialog() {
    showDialog(
      context: context,
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
              _navigateToVendorRegistration();
            },
            child: const Text('Become a Vendor'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    Logger.lifecycle('MarketplaceScreen disposed');
    super.dispose();
  }

  Future<void> _checkVendorStatus() async {
    try {
      setState(() {
        _isCheckingVendorStatus = true;
      });

      // Get current user - using User? to handle nullable User
      try {
        final user = context.read<User?>();
        
        if (user == null) {
          Logger.state('No user found in provider');
          setState(() {
            _isCheckingVendorStatus = false;
            // We'll handle the null user case in the UI
          });
          return;
        }
        
        _memberId = user.memberId;

        if (_memberId != null) {
          // Check if user is a vendor
          final isVendor = await _marketplaceRepository.isMemberVendor(_memberId!);

          if (isVendor && mounted) {
            // Get vendor ID if user is a vendor
            final vendorResult = await _marketplaceRepository.getVendorByMemberId(_memberId!);
            
            vendorResult.fold(
              (failure) {
                Logger.error('Failed to get vendor details', failure);
                setState(() {
                  _isVendor = isVendor;
                  _isCheckingVendorStatus = false;
                });
              },
              (vendor) {
                setState(() {
                  _isVendor = true;
                  _vendorId = vendor.id;
                  _isCheckingVendorStatus = false;
                });
              },
            );
          } else if (mounted) {
            setState(() {
              _isVendor = false;
              _isCheckingVendorStatus = false;
            });
          }
        } else {
          setState(() {
            _isCheckingVendorStatus = false;
          });
        }
      } catch (providerError) {
        // Handle the case where the provider is not available
        Logger.state('Provider error: $providerError');
        
        // For development/testing purposes, we could set a hardcoded member ID
        // _memberId = 'test_member_id';
        
        setState(() {
          _isCheckingVendorStatus = false;
        });
      }
    } catch (e) {
      Logger.error('Error checking vendor status', e);
      if (mounted) {
        setState(() {
          _isCheckingVendorStatus = false;
        });
      }
    }
  }

  void _navigateToVendorRegistration() {
    if (_memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to become a vendor'),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'Login',
            textColor: AppColors.white,
            onPressed: () {
              // Navigate to login screen
              Navigator.pushNamed(context, '/login');
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      
      // For development/testing purposes, uncomment this to bypass the login requirement
      // This is useful during development to test the vendor registration flow
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        // Only in debug mode
        Logger.data('DEBUG MODE: Using test member ID for vendor registration');
        Navigator.pushNamed(
          context,
          '/vendor-registration',
          arguments: {
            'memberId': 'test_member_id',
          },
        ).then((_) {
          // Refresh vendor status when returning from registration
          _checkVendorStatus();
        });
        return;
      }
      
      return;
    }
    
    Navigator.pushNamed(
      context,
      '/vendor-registration',
      arguments: {
        'memberId': _memberId!,
      },
    ).then((_) {
      // Refresh vendor status when returning from registration
      _checkVendorStatus();
    });
  }

  void _navigateToVendorProfile() {
    if (_vendorId == null) return;
    
    Navigator.pushNamed(
      context,
      '/vendor-profile',
      arguments: {
        'vendorId': _vendorId!,
        'isOwner': true,
      },
    );
  }

  void _navigateToInventoryManagement() {
    if (_vendorId == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryManagementScreen(
          vendorId: _vendorId!,
        ),
      ),
    );
  }

  void _navigateToNewSale() {
    if (_vendorId == null) return;
    
    Navigator.pushNamed(
      context,
      '/vendor-sales-tab',
      arguments: {
        'vendorId': _vendorId!,
      },
    );
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = _selectedCategory != null
          ? await _marketplaceRepository.getProductsByCategory(_selectedCategory!)
          : await _marketplaceRepository.searchProducts('');

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load products';
          });
        },
        (products) {
          // Extract unique categories
          final categories = products
              .map((p) => p.category)
              .toSet()
              .toList()
            ..sort();

          setState(() {
            _isLoading = false;
            _products = products;
            _categories = categories;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadProducts();
  }

  void _searchProducts(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _marketplaceRepository.searchProducts(query);

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to search products';
          });
        },
        (products) {
          setState(() {
            _isLoading = false;
            _products = products;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }
  
  Future<void> _scanInvoiceQR() async {
    try {
      // Navigate to the QR scanner screen
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const ScanQRScreen(),
          fullscreenDialog: true,
        ),
      );
      
      if (result != null && mounted) {
        // Check if the QR code is a valid invoice QR code
        if (result.startsWith('vimbisopay://invoice/')) {
          // Extract the invoice ID from the QR code
          final invoiceId = result.substring('vimbisopay://invoice/'.length);
          
          // Navigate to the buyer invoice detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BuyerInvoiceDetailScreen(
                invoiceId: invoiceId,
              ),
            ),
          );
        } else {
          // Show error message for invalid QR code
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid invoice QR code'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Error scanning invoice QR code', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR code: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }
  
  void _showVendorActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.point_of_sale, color: AppColors.primary),
            title: const Text('New Sale'),
            onTap: () {
              Navigator.pop(context);
              _navigateToNewSale();
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2, color: AppColors.primary),
            title: const Text('Manage Inventory'),
            onTap: () {
              Navigator.pop(context);
              _navigateToInventoryManagement();
            },
          ),
          ListTile(
            leading: const Icon(Icons.storefront, color: AppColors.primary),
            title: const Text('Vendor Profile'),
            onTap: () {
              Navigator.pop(context);
              _navigateToVendorProfile();
            },
          ),
        ],
      ),
    );
  }
  
  void _showDebugInfo() {
    showDialog(
      context: context,
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
              Text('Member ID: ${_memberId ?? 'null'}'),
              const SizedBox(height: 8),
              
              const Text(
                'Vendor Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Is Vendor: $_isVendor'),
              Text('Vendor ID: ${_vendorId ?? 'null'}'),
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
              setState(() {
                _memberId = 'test_member_id';
                _isVendor = true;  // Force vendor status to true
                _vendorId = 'v_test';  // Set a test vendor ID
              });
              Logger.data('DEBUG MODE: Set test vendor values - memberId: $_memberId, isVendor: $_isVendor, vendorId: $_vendorId');
              ScaffoldMessenger.of(context).showSnackBar(
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
              setState(() {
                _memberId = null;
                _isVendor = false;
                _vendorId = null;
              });
              Logger.data('DEBUG MODE: Reset debug values');
              ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          // Scan Invoice QR Code button
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Invoice',
            onPressed: _scanInvoiceQR,
          ),
          if (_isVendor)
            IconButton(
              icon: const Icon(Icons.storefront),
              tooltip: 'Vendor Actions',
              onPressed: _showVendorActionSheet,
            ),
          // Debug button - only visible in debug mode
          if (const bool.fromEnvironment('dart.vm.product') == false)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug Info',
              onPressed: _showDebugInfo,
            ),
        ],
      ),
      floatingActionButton: _isVendor ? FloatingActionButton.extended(
        onPressed: _showVendorActionSheet,
        icon: const Icon(Icons.storefront),
        label: const Text('Vendor Actions'),
        backgroundColor: AppColors.primary,
      ) : null,
      body: SafeArea(
        child: Column(
          children: [
            // Vendor CTA Banner
            if (!_isCheckingVendorStatus) _buildVendorCTA(),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onSubmitted: _searchProducts,
              ),
            ),
            
            // Category filter
            if (_categories.isNotEmpty)
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _selectedCategory == null,
                        onSelected: (selected) {
                          if (selected) {
                            _selectCategory(null);
                          }
                        },
                      ),
                    ),
                    ..._categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            if (selected) {
                              _selectCategory(category);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            
            // Loading indicator or error message
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _loadProducts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            // Product grid
            else if (_products.isNotEmpty)
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    return _buildProductCard(product);
                  },
                ),
              )
            // Empty state
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No products found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try a different search or category',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorCTA() {
    if (_isVendor) {
      // Show quick actions for vendors
      return Card(
        margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vendor Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _navigateToInventoryManagement,
                      icon: const Icon(Icons.inventory_2),
                      label: const Text('Inventory'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _navigateToNewSale,
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('New Sale'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // Show CTA for non-vendors
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
                    // Add debug logging to help troubleshoot
                    Logger.data('Become a Vendor button tapped, memberId: $_memberId');
                    _navigateToVendorRegistration();
                  },
                  icon: const Icon(Icons.storefront),
                  label: const Text('Become a Vendor'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_memberId == null) ...[
                const SizedBox(height: 8),
                Text(
                  'You need to be logged in to become a vendor.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  /// Builds the product image widget based on the image URL type.
  Widget _buildProductImage(Product product) {
    if (product.imageUrls.isEmpty || product.imageUrls.first == 'https://example.com/product_placeholder.jpg') {
      // Show placeholder if no image
      return Container(
        color: AppColors.textGray.withOpacity(0.3),
        child: Center(
          child: Icon(
            Icons.image,
            color: AppColors.textGray,
          ),
        ),
      );
    }
    
    final imageUrl = product.imageUrls.first;
    
    if (imageUrl.startsWith('file://')) {
      // Show local file image
      final filePath = imageUrl.substring(7); // Remove 'file://' prefix
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('Error loading local image: $filePath', error);
          return Container(
            color: AppColors.textGray.withOpacity(0.3),
            child: Center(
              child: Icon(
                Icons.image_not_supported,
                color: AppColors.textGray,
              ),
            ),
          );
        },
      );
    } else {
      // Show remote image
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.textGray.withOpacity(0.2),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.textGray.withOpacity(0.3),
          child: Center(
            child: Icon(
              Icons.image_not_supported,
              color: AppColors.textGray,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildProductCard(Product product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: () async {
          // Get the vendor for this product
          final vendorResult = await _marketplaceRepository.getVendor(product.vendorId);
          
          vendorResult.fold(
            (failure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(failure.message ?? 'Failed to load vendor'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            (vendor) {
              // Navigate to vendor profile screen
              Navigator.pushNamed(
                context,
                '/vendor-profile',
                arguments: {
                  'vendorId': vendor.id,
                  'isOwner': false,
                },
              );
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            AspectRatio(
              aspectRatio: 1.0,
              child: _buildProductImage(product),
            ),
            // Product info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.formattedPrice,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Row(
                        children: [
                          Icon(
                            product.isAvailable
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 16,
                            color: product.isAvailable
                                ? AppColors.success
                                : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product.isAvailable
                                  ? 'Available'
                                  : 'Unavailable',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.isAvailable
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
