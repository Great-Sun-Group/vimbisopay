import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // For ScrollDirection
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/product.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/location_service.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vimbisopay_app/presentation/widgets/marketplace/product_card.dart';
import 'package:vimbisopay_app/presentation/widgets/marketplace/marketplace_states.dart';
import 'package:vimbisopay_app/presentation/widgets/marketplace/vendor_cta_widget.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/inventory_management_screen.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';
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
  late ScrollController _scrollController;
  bool _isLoading = true;
  bool _isInitializing = true; // Track initialization state
  String _errorMessage = '';
  List<Product> _products = [];
  bool _isVendor = false;
  bool _isCheckingVendorStatus = false;
  String? _memberId;
  String? _vendorId;
  String? _personalAccountId;
  double? _latitude;
  double? _longitude;
  bool _isRequestingLocation = false;
  bool _showBrowseMode = false; // Default to My Store mode for vendors
  bool _isFabVisible = true; // Track FAB visibility

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('MarketplaceScreen initialized');
    
    // Initialize scroll controller
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    
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
  
  void _scrollListener() {
    // Show/hide FAB based on scroll direction
    if (_scrollController.hasClients) {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        // Scrolling down - hide FAB
        if (_isFabVisible) {
          setState(() => _isFabVisible = false);
        }
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward ||
                (_scrollController.hasClients && _scrollController.position.pixels == 0)) {
        // Scrolling up or at the top - show FAB
        if (!_isFabVisible) {
          setState(() => _isFabVisible = true);
        }
      }
    }
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
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
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
      // Always use "a" as the default search query to ensure products are loaded
      final result = await _marketplaceRepository.searchProducts(
        'a', // Default search with "a" to get products
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
          
          setState(() {
            _isLoading = false;
            _products = filteredProducts;
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
  
  // Helper method to check if extra padding is needed for FAB
  double _getBottomPadding() {
    return _isVendor && _isFabVisible ? 80.0 : 16.0;
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
      return MarketplaceStates.buildInitializingState();
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
      // Extremely simple FAB implementation
      floatingActionButton: _isVendor && _isFabVisible ? 
        GestureDetector(
          onTap: _showVendorActionSheet,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ) : null,
      body: SafeArea(
        child: Column(
          children: [
            // Vendor CTA Banner
            if (!_isCheckingVendorStatus)
              VendorCTAWidget(
                isVendor: _isVendor,
                showBrowseMode: _showBrowseMode,
                onModeChanged: (selection) {
                  setState(() {
                    _showBrowseMode = selection.first;
                  });
                  // Reload products to apply filtering
                  _loadProducts();
                },
                onBecomeVendor: _navigateToVendorRegistration,
                getUserFunction: () => ServiceLocator.databaseHelper.getUser(),
                canBecomeVendorFunction: _canBecomeVendor,
                isCheckingVendorStatus: _isCheckingVendorStatus,
              ),
            
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
            
            // Loading indicator or error message
            if (_isLoading)
              Expanded(
                child: MarketplaceStates.buildLoadingState(),
              )
            else if (_errorMessage.isNotEmpty)
              Expanded(
                child: MarketplaceStates.buildErrorState(
                  errorMessage: _errorMessage,
                  onRetry: _loadProducts,
                ),
              )
            // Product grid
            else if (_products.isNotEmpty)
              Expanded(
                child: GridView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, _getBottomPadding()), // Add bottom padding when FAB is present
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    return ProductCard(product: _products[index]);
                  },
                ),
              )
            // Empty state
            else
              Expanded(
                child: MarketplaceStates.buildEmptyState(),
              ),
          ],
        ),
      ),
    );
  }
}
