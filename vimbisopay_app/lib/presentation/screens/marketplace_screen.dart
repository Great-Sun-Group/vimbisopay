import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/location_service.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/inventory_management_screen.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/product_detail_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/store_information_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/vendor_profile_screen.dart';

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
  final LocationService _locationService = ServiceLocator.locationService;
  bool _isLoading = true;
  bool _isInitializing = true; // Track initialization state
  String _errorMessage = '';
  List<Product> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isVendor = false;
  bool _isCheckingVendorStatus = false;
  String? _memberId;
  String? _vendorId;
  String? _personalAccountId;
  double? _latitude;
  double? _longitude;
  bool _isRequestingLocation = false;
  bool _showBrowseMode = true; // Default to browse mode for vendors

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('MarketplaceScreen initialized');
    _checkVendorStatus().then((_) {
      // Request location permission and load products for all users (including vendors)
      _requestLocationPermission().then((_) {
        _loadProducts();
        _checkFirstTimeVisit();
        
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      });
    });
  }
  
  /// Requests location permission from the user.
  ///
  /// This method shows a dialog explaining why we need location permission
  /// and then requests the permission if the user agrees.
  Future<void> _requestLocationPermission() async {
    if (_isRequestingLocation) return;
    
    setState(() {
      _isRequestingLocation = true;
    });
    
    try {
      Logger.data('[MARKETPLACE] Checking if location services are enabled');
      
      // Check if location services are enabled
      bool servicesEnabled = await _locationService.checkLocationServicesEnabled();
      if (!servicesEnabled) {
        Logger.data('[MARKETPLACE] Location services are disabled');
        setState(() {
          _isRequestingLocation = false;
        });
        return;
      }
      
      // Check if permission is already granted
      bool hasPermission = await _locationService.checkLocationPermission();
      if (hasPermission) {
        Logger.data('[MARKETPLACE] Location permission already granted');
        // Get current location
        await _getCurrentLocation();
        setState(() {
          _isRequestingLocation = false;
        });
        return;
      }
      
      // Show a dialog explaining why we need location permission
      if (mounted) {
        final shouldRequest = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission'),
            content: const Text(
              'To help you find nearby products and services, we need your location. '
              'Would you like to grant location permission?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not Now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ) ?? false;
        
        if (!shouldRequest) {
          Logger.data('[MARKETPLACE] User declined to request location permission');
          setState(() {
            _isRequestingLocation = false;
          });
          return;
        }
      }
      
      // Request permission
      final permissionGranted = await _locationService.requestLocationPermission();
      Logger.data('[MARKETPLACE] Location permission request result: $permissionGranted');
      
      if (permissionGranted) {
        // Get current location
        await _getCurrentLocation();
      }
    } catch (e) {
      Logger.error('[MARKETPLACE] Error requesting location permission', e);
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingLocation = false;
        });
      }
    }
  }
  
  /// Gets the current location if available.
  Future<void> _getCurrentLocation() async {
    try {
      Logger.data('[MARKETPLACE] Getting current location');
      
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        Logger.data('[MARKETPLACE] Got location: (${position.latitude}, ${position.longitude})');
      } else {
        Logger.error('[MARKETPLACE] Failed to get location');
      }
    } catch (e) {
      Logger.error('[MARKETPLACE] Error getting current location', e);
    }
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

      // Get current user from database instead of Provider
      final user = await ServiceLocator.databaseHelper.getUser();
      
      if (user == null) {
        Logger.state('No user found in database');
        setState(() {
          _isCheckingVendorStatus = false;
          // We'll handle the null user case in the UI
        });
        return;
      }
      
      _memberId = user.memberId;
      
      // Find the user's personal account ID
      if (user.dashboard != null && user.dashboard!.accounts.isNotEmpty) {
        // Try to find an account with accountType PERSONAL
        for (final account in user.dashboard!.accounts) {
          if (account.accountType == 'PERSONAL') {
            _personalAccountId = account.accountID;
            Logger.data('[MARKETPLACE] Found PERSONAL account: $_personalAccountId (${account.accountName})');
            break;
          }
        }
        
        // If no account with accountType PERSONAL found, try to find by name
        if (_personalAccountId == null) {
          for (final account in user.dashboard!.accounts) {
            if (account.accountName.toUpperCase().contains('PERSONAL')) {
              _personalAccountId = account.accountID;
              Logger.data('[MARKETPLACE] Found account with PERSONAL in name: $_personalAccountId (${account.accountName})');
              break;
            }
          }
        }
      }

      if (_memberId != null) {
        // Check if user is a vendor
        final isVendor = await _marketplaceRepository.isMemberVendor(_memberId!);

        if (isVendor && mounted) {
          // If user is a vendor, set the vendor ID to the member ID
          // We don't need to call getVendorByMemberId as the logged in user is already a vendor
          setState(() {
            _isVendor = true;
            _vendorId = _memberId; // Use member ID as vendor ID
            _isCheckingVendorStatus = false;
          });
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
    // Get user data from database if available
    ServiceLocator.databaseHelper.getUser().then((user) {
      if (user == null) {
        // Show login prompt if user is not logged in
        ScaffoldMessenger.of(context).showSnackBar(
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
        context,
        '/vendor-registration',
        arguments: {
          'memberId': user.memberId,
          'user': user, // Pass the entire user object to pre-populate fields
        },
      ).then((_) async {
        // Refresh vendor status when returning from registration
        _checkVendorStatus();
        
        // Force rebuild of the UI to reflect the updated vendor status
        if (mounted) {
          setState(() {
            Logger.data('[MARKETPLACE] Forcing UI rebuild after vendor registration');
          });
        }
      });
    });
  }

  // Check if the user is allowed to become a vendor
  bool _canBecomeVendor(User? user) {
    // If there's no user, don't allow becoming a vendor as guest
    if (user == null) return false;
    
    // Check the activateMarket property directly on the User object
    // This property is set from either the User.activateMarket field or
    // from the Dashboard.activateMarket field for backward compatibility
    // activateMarket == false means we should prompt the user to become a vendor
    // activateMarket == true means the user is already a vendor
    return !user.activateMarket;
  }

  void _navigateToVendorProfile({bool replace = false}) {
    if (_vendorId == null) return;
    
    if (replace) {
      // Replace current route to prevent back navigation to marketplace
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VendorProfileScreen(
            vendorId: _vendorId!,
            isOwner: true,
          ),
        ),
      );
    } else {
      // Regular push for normal navigation
      Navigator.pushNamed(
        context,
        '/vendor-profile',
        arguments: {
          'vendorId': _vendorId!,
          'isOwner': true,
        },
      );
    }
  }
  
  void _navigateToStoreInformation() {
    if (_vendorId == null) return;
    
    // Use personal account ID if available, otherwise use vendor ID
    final storeId = _personalAccountId ?? _vendorId!;
    Logger.data('[MARKETPLACE] Navigating to store information with ID: $storeId');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreInformationScreen(
          storeId: storeId,
          isOwner: true,
        ),
      ),
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
    // No need to check for vendorId or pass it as an argument
    // since VendorSalesTabScreen now uses the current user
    Navigator.pushNamed(
      context,
      '/vendor-sales-tab',
    );
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // If we have a selected category, use getProductsByCategory
      // Otherwise use searchProducts with location data if available
      final result = _selectedCategory != null
          ? await _marketplaceRepository.getProductsByCategory(_selectedCategory!)
          : await _marketplaceRepository.searchProducts(
              '', // Empty query or "a" will be used as default in the repository
              latitude: _latitude,
              longitude: _longitude,
            );

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load products';
          });
        },
        (products) {
          // If user is a vendor in browse mode, filter out their own products
          List<Product> filteredProducts = products;
          if (_isVendor && _showBrowseMode && _vendorId != null) {
            Logger.data('[MARKETPLACE] Filtering out vendor\'s own products. Vendor ID: $_vendorId');
            filteredProducts = products.where((product) => product.vendorId != _vendorId).toList();
            Logger.data('[MARKETPLACE] Filtered ${products.length - filteredProducts.length} products');
          }
          
          // Extract unique categories
          final categories = filteredProducts
              .map((p) => p.category)
              .toSet()
              .toList()
            ..sort();

          setState(() {
            _isLoading = false;
            _products = filteredProducts;
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
    Navigator.pushNamed(
      context,
      '/search-results',
      arguments: {
        'category': category,
        'vendorId': _isVendor && _showBrowseMode ? _vendorId : null,
        'filterOwnProducts': _isVendor && _showBrowseMode,
      },
    );
  }

  void _searchProducts(String query) {
    Navigator.pushNamed(
      context,
      '/search-results',
      arguments: {
        'query': query,
        'vendorId': _isVendor && _showBrowseMode ? _vendorId : null,
        'filterOwnProducts': _isVendor && _showBrowseMode,
      },
    );
  }
  
  Future<void> _scanInvoiceQR() async {
    try {
      // Navigate to the QR scanner screen
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => const ScanQRScreen(
            showDebugOptions: false, // Disable debug options for production
          ),
          fullscreenDialog: true,
        ),
      );
      
      if (result != null && mounted) {
        String? invoiceId;
        
        // Check if the QR code is a valid invoice QR code in the old format
        if (result.startsWith('vimbisopay://invoice/')) {
          // Extract the invoice ID from the QR code
          invoiceId = result.substring('vimbisopay://invoice/'.length);
          Logger.data('QR code scanned in old format: $result, extracted invoice ID: $invoiceId');
        } 
        // Check if the QR code is in the new URL format
        else if (result.startsWith('https://mycredex.app/getInvoice/')) {
          // Extract the invoice ID from the URL
          invoiceId = result.substring('https://mycredex.app/getInvoice/'.length);
          Logger.data('QR code scanned in new format: $result, extracted invoice ID: $invoiceId');
        }
        
        if (invoiceId != null && invoiceId.isNotEmpty) {
          // Show loading indicator
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing invoice...'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Navigate to the buyer invoice detail screen with the non-nullable invoiceId
          final String nonNullableInvoiceId = invoiceId; // Create a non-nullable copy
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BuyerInvoiceDetailScreen(
                invoiceId: nonNullableInvoiceId,
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
          // Toggle between browse mode and vendor mode
          SwitchListTile(
            title: const Text('Browse Mode'),
            subtitle: const Text('Discover products from other vendors'),
            value: _showBrowseMode,
            secondary: Icon(
              _showBrowseMode ? Icons.search : Icons.storefront,
              color: AppColors.primary,
            ),
            onChanged: (value) {
              setState(() {
                _showBrowseMode = value;
              });
              Navigator.pop(context);
              // Reload products to apply filtering
              _loadProducts();
            },
          ),
          const Divider(),
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
          ListTile(
            leading: const Icon(Icons.store, color: AppColors.primary),
            title: const Text('Store Information'),
            onTap: () {
              Navigator.pop(context);
              _navigateToStoreInformation();
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
    // Show a loading indicator during initialization
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Marketplace'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
        ),
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    // Only build the full UI once initialization is complete
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
      // Show mode toggle for vendors with improved layout
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
                _showBrowseMode 
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
                  selected: {_showBrowseMode},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _showBrowseMode = selection.first;
                    });
                    // Reload products to apply filtering
                    _loadProducts();
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Always get the latest user data from the database
      // This ensures we have the most up-to-date activateMarket status
      Logger.data('[MARKETPLACE] Getting latest user data from database for vendor CTA');
      return FutureBuilder<User?>(
        future: ServiceLocator.databaseHelper.getUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final user = snapshot.data;
          final canBecomeVendor = _canBecomeVendor(user);
          
          Logger.data('[MARKETPLACE] User activateMarket status: ${user?.activateMarket}');
          Logger.data('[MARKETPLACE] Can become vendor: $canBecomeVendor');
          
          return _buildVendorCTAContent(canBecomeVendor);
        },
      );
    }
  }
  
  Widget _buildVendorCTAContent(bool canBecomeVendor) {
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
                  _navigateToVendorRegistration();
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: product.id,
              ),
            ),
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
